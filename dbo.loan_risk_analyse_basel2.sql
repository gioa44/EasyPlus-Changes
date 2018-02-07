ALTER PROCEDURE dbo.loan_risk_analyse_basel2
	@loan_id int,
	@date smalldatetime,
	@principal money, 
	@overdue_principal money,
	@calloff_principal money,
	@writeoff_principal money,

	@category_1 money OUTPUT,
	@category_2 money OUTPUT,
	@category_3 money OUTPUT,
	@category_4 money OUTPUT,
	@category_5 money OUTPUT,
	@category_6 money OUTPUT,
	@max_category_level tinyint OUTPUT
AS

SET NOCOUNT ON;

IF @writeoff_principal <> $0.00
BEGIN
	SET @category_1 = $0.00
	SET @category_2 = $0.00
	SET @category_3 = $0.00
	SET @category_4 = $0.00
	SET @category_5 = $0.00
	SET @category_6 = @writeoff_principal
	SET @max_category_level = 6

	RETURN 0
END

DECLARE
	@non_auto_calc bit,
	@max_category_level_auto tinyint
	
SET @non_auto_calc = NULL
SET @max_category_level_auto = 1
	

IF EXISTS(SELECT * FROM dbo.LOAN_OPS (NOLOCK) WHERE LOAN_ID = @loan_id AND OP_TYPE = 241 /*dbo.loan_const_op_restructure_risks()*/)
BEGIN
	DECLARE
		@move_category_1 int,
		@move_category_2 int,
		@move_category_3 int,
		@move_category_4 int,
		@move_category_5 int
	
	SELECT TOP 1
		@move_category_1 = ISNULL(OP_DATA.value('(row/@MOVE_CATEGORY_1)[1]', 'int'), $0.00),
		@move_category_2 = ISNULL(OP_DATA.value('(row/@MOVE_CATEGORY_2)[1]', 'int'), $0.00),
		@move_category_3 = ISNULL(OP_DATA.value('(row/@MOVE_CATEGORY_3)[1]', 'int'), $0.00),
		@move_category_4 = ISNULL(OP_DATA.value('(row/@MOVE_CATEGORY_4)[1]', 'int'), $0.00),
		@move_category_5 = ISNULL(OP_DATA.value('(row/@MOVE_CATEGORY_5)[1]', 'int'), $0.00),
		@non_auto_calc = ISNULL(OP_DATA.value('(row/@NON_AUTO_CALC)[1]', 'bit'), 0)
	FROM dbo.LOAN_OPS (NOLOCK)
	WHERE LOAN_ID = @loan_id AND OP_TYPE = 241
	ORDER BY OP_ID DESC
	
	IF ISNULL(@non_auto_calc, 0) = 1
	BEGIN
		SELECT 
			@category_1 = CASE WHEN @category_1 IS NULL THEN CATEGORY_1 ELSE @category_1 END,
			@category_2 = CASE WHEN @category_2 IS NULL THEN CATEGORY_2 ELSE @category_2 END,
			@category_3 = CASE WHEN @category_3 IS NULL THEN CATEGORY_3 ELSE @category_3 END,
			@category_4 = CASE WHEN @category_4 IS NULL THEN CATEGORY_4 ELSE @category_4 END,
			@category_5 = CASE WHEN @category_5 IS NULL THEN CATEGORY_5 ELSE @category_5 END,
			@category_6 = CASE WHEN @category_6 IS NULL THEN CATEGORY_6 ELSE @category_6 END,
			@max_category_level = MAX_CATEGORY_LEVEL 
		FROM dbo.LOAN_DETAILS
		WHERE LOAN_ID = @loan_id

		RETURN 0
	END

	IF @move_category_1 <> 1 SET @max_category_level_auto = @move_category_1
	IF @move_category_2 <> 2 SET @max_category_level_auto = @move_category_2
	IF @move_category_3 <> 3 SET @max_category_level_auto = @move_category_3
	IF @move_category_4 <> 4 SET @max_category_level_auto = @move_category_4
	IF @move_category_5 <> 5 SET @max_category_level_auto = @move_category_5
END

DECLARE
	@max_category_level_ tinyint

SELECT @max_category_level_ = MAX_CATEGORY_LEVEL 
FROM dbo.LOAN_DETAILS (NOLOCK)
WHERE LOAN_ID = @loan_id

DECLARE
	@client_no int,
	@prolonged bit,
	@raiting varchar(3),
	@loan_iso TISO,
	@ensure_amount money,
	@loan_amount money,
	@loan_ensured_amount money,
	@loan_not_ensured_amount money,
	@type_id int,
	@product_id int,
	@reserve_max_category bit,
	@ensure_type tinyint,
	@_credit_line_id int,
	@is_guarantee bit,

	@a money,
	@b money,
	@c money,
	@d money

SELECT @client_no = CLIENT_NO, @product_id = PRODUCT_ID, @loan_iso = ISO, @type_id = RISK_TYPE, 
	@reserve_max_category = RESERVE_MAX_CATEGORY, @ensure_type = ENSURE_TYPE, @_credit_line_id = CREDIT_LINE_ID,
	@is_guarantee = ISNULL(GUARANTEE, 0)
FROM dbo.LOANS (NOLOCK)
WHERE LOAN_ID = @loan_id

SELECT @raiting = RAITING
FROM dbo.CLIENT_EXTENSIONS (NOLOCK)
WHERE CLIENT_NO = @client_no

SET @prolonged = 0
--IF EXISTS(SELECT * FROM dbo.LOAN_OPS WHERE LOAN_ID = @loan_id AND OP_TYPE = 130 /*dbo.loan_const_op_prolongation()*/)
--	SET @prolonged = 1

SET @loan_amount = @principal + @overdue_principal + @calloff_principal
SET @loan_ensured_amount = $0.00
SET @loan_not_ensured_amount = @loan_amount

DECLARE
	@min_overdue_date smalldatetime,
	@overdue_days int

SELECT @min_overdue_date = MIN(OVERDUE_DATE)
FROM dbo.LOAN_DETAIL_OVERDUE (NOLOCK)
WHERE LOAN_ID = @loan_id AND (OVERDUE_PRINCIPAL <> $0.00 OR OVERDUE_PERCENT <> $0.00)

SET @overdue_days = DATEDIFF(day, ISNULL(@min_overdue_date, @date), @date)

SET @category_1 = $0.00
SET @category_2 = $0.00
SET @category_3 = $0.00
SET @category_4 = $0.00
SET @category_5 = $0.00
SET @category_6 = $0.00

IF @product_id IN (7, 14)
BEGIN
	SET @category_1 = @loan_amount
	SET @max_category_level = 1
END
ELSE
BEGIN
	IF @overdue_days <= 0
	BEGIN
		SET @category_1 = @loan_amount
		SET @max_category_level = 1
	END

	IF @overdue_days > 0 AND @overdue_days <= 60
	BEGIN
		SET @category_2 = @loan_amount
		SET @max_category_level = 2
	END;

	IF @overdue_days > 60 AND @overdue_days <= 160
	BEGIN
		SET @category_3 = @loan_amount
		SET @max_category_level = 3
	END;

	IF @overdue_days > 160 AND @overdue_days <= 250
	BEGIN
		SET @category_4 = @loan_amount
		SET @max_category_level = 4
	END;

	IF @overdue_days > 250
	BEGIN
		SET @category_5 = @loan_amount
		SET @max_category_level = 5
	END;
END

IF (@non_auto_calc IS NOT NULL) AND (@non_auto_calc = 0) AND (@max_category_level < @max_category_level_auto)
BEGIN
	SELECT 
		@category_1 = CATEGORY_1,
		@category_2 = CATEGORY_2,
		@category_3 = CATEGORY_3,
		@category_4 = CATEGORY_4,
		@category_5 = CATEGORY_5,
		@category_6 = CATEGORY_6
	FROM dbo.LOAN_DETAILS
	WHERE LOAN_ID = @loan_id

	SET @max_category_level = @max_category_level_auto
	SET @category_1 = CASE WHEN @max_category_level = 1 THEN ISNULL(@category_1, $0.00) + ISNULL(@category_2, $0.00) + ISNULL(@category_3, $0.00) + ISNULL(@category_4, $0.00) + ISNULL(@category_5, $0.00) ELSE NULL END
	SET @category_2 = CASE WHEN @max_category_level = 2 THEN ISNULL(@category_1, $0.00) + ISNULL(@category_2, $0.00) + ISNULL(@category_3, $0.00) + ISNULL(@category_4, $0.00) + ISNULL(@category_5, $0.00) ELSE NULL END
	SET @category_3 = CASE WHEN @max_category_level = 3 THEN ISNULL(@category_1, $0.00) + ISNULL(@category_2, $0.00) + ISNULL(@category_3, $0.00) + ISNULL(@category_4, $0.00) + ISNULL(@category_5, $0.00) ELSE NULL END
	SET @category_4 = CASE WHEN @max_category_level = 4 THEN ISNULL(@category_1, $0.00) + ISNULL(@category_2, $0.00) + ISNULL(@category_3, $0.00) + ISNULL(@category_4, $0.00) + ISNULL(@category_5, $0.00) ELSE NULL END
	SET @category_5 = CASE WHEN @max_category_level = 5 THEN ISNULL(@category_1, $0.00) + ISNULL(@category_2, $0.00) + ISNULL(@category_3, $0.00) + ISNULL(@category_4, $0.00) + ISNULL(@category_5, $0.00) ELSE NULL END
END

RETURN 0
GO
