SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[LOAN_SP_EXEC_OP]
	@doc_rec_id int OUTPUT,
	@op_id int,
	@user_id int,
	@by_processing bit = 0
AS
SET NOCOUNT ON

DECLARE @e int, @r int

DECLARE
	@loan_end_date smalldatetime

DECLARE
	@loan_id int,
	@credit_line_id int,
	@op_date smalldatetime,
	@op_type smallint,
	@op_state tinyint,
	@amount money,
	@pmt money,
	@op_note varchar(255),
	@owner int,
	@note_rec_id int,
	@update_data bit,
	@update_schedule bit,
	@auth_owner int,
	@op_data xml,
	@op_loan_details xml,
	@overdue_date smalldatetime,
	@op_ext_xml_1 xml,
	@op_ext_xml_2 xml

DECLARE
	@calc_date					smalldatetime,
	@prev_step					smalldatetime,
	@nu_principal				money,
	@nu_interest				money,
	
	@principal					money,
	@principal_					money,

	@max_category_level			tinyint,
	@max_category_level_		tinyint,
	@category_1					money,
	@category_2					money,
	@category_3					money,
	@category_4					money,
	@category_5					money,
	@category_6					money,

	@loan_risk_rate_1			money,
	@loan_risk_rate_2			money,
	@loan_risk_rate_3			money,
	@loan_risk_rate_4			money,
	@loan_risk_rate_5			money

DECLARE
	@overdue_percent_penalty money, 
	@overdue_principal_penalty money, 
	@overdue_percent money,
	@late_percent money, 
	@late_percent_ money, 
	@overdue_principal money, 
	@overdue_principal_ money, 
	@late_principal money, 
	@late_principal_ money, 
	@overdue_principal_interest money,
	@interest money,
	@prepayment money,
	@prepayment_penalty money,
	@payment_type tinyint,
	
	@overdue_insurance money,
	@overdue_service_fee money,

	@defered_interest money,
	@defered_overdue_interest money,
	@defered_penalty money,
	@defered_fine money,
	@remaining_fee money


DECLARE
	@new_resp_user_id int,
	@penalty_flags int,
	@calloff_principal_penalty money,
	@calloff_percent_penalty money,
	@writeoff_principal money,
	@writeoff_percent money,
	@writeoff_penalty money,
	@writeoff_principal_penalty money,
	@writeoff_percent_penalty money

DECLARE
	@intrate money,
	@penalty_intrate money,
	@notused_intrate money,
	@prepayment_intrate money,
	@payment_day money,
	@loan_state int,
	@payment_interval_type int,
	@schedule_type int,
	@grace_type bit,
	@grace_steps int,
	@disburse_type int

DECLARE
	@purpose_type int,
	@group_id int,
	@coresponsible_user_id int,
	@prepayment_step int,
	@interest_flags int,
	@prepayment_flags int,
	@reserve_max_category bit

DECLARE
	@interest_transh_corrected money,
	@nu_interest_transh_corrected money,
	@sched_date_after_transh smalldatetime,
	@interest_correction money,
	@nu_interest_correction money

DECLARE
	@tmp_1_1 money,	@tmp_1_2 money,
	@tmp_2_1 money,	@tmp_2_2 money


SET @note_rec_id = NULL
SET @op_loan_details = NULL

SELECT @loan_id=LOAN_ID, @op_date=OP_DATE, @op_type=OP_TYPE, @op_state=OP_STATE, @amount=AMOUNT, @op_note=OP_NOTE,
	   @owner=[OWNER], @update_data=UPDATE_DATA, @update_schedule=UPDATE_SCHEDULE, @auth_owner=AUTH_OWNER,
	   @op_ext_xml_1 = OP_EXT_XML_1, @op_ext_xml_2 = OP_EXT_XML_2
FROM dbo.LOAN_OPS WHERE OP_ID=@op_id
SELECT @r = @@ROWCOUNT, @e = @@ERROR
IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

IF @op_state = 0xFF BEGIN RAISERROR ('ÏÐÄÒÀÝÉÀ ÛÄÓÒÖËÄÁÖËÉÀ ÓáÅÀ ÌÏÌáÌÀÒÄÁËÉÓ ÌÉÄÒ',16,1) RETURN (1) END

IF @update_data = 1
BEGIN
	EXEC @r = dbo.LOAN_SP_BACKUP_LOAN_DATA @op_id = @op_id, @loan_id=@loan_id
	IF @@ERROR <> 0 OR @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
END

IF @update_schedule = 1 
BEGIN
	EXEC @r = dbo.LOAN_SP_BACKUP_LOAN_SCHEDULE @op_id = @op_id, @loan_id=@loan_id
	IF @@ERROR <> 0 OR @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	IF EXISTS (SELECT * FROM dbo.LOAN_OP_SCHEDULE (NOLOCK) WHERE OP_ID = @op_id)
	BEGIN
		EXEC @r = dbo.LOAN_SP_RESTORE_OP_LOAN_SCHEDULE @op_id = @op_id, @loan_id=@loan_id
		IF @@ERROR <> 0 OR @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

		IF @op_type NOT IN (dbo.loan_const_op_payment(), dbo.loan_const_op_debt_defere(), dbo.loan_const_op_guar_payment())
		BEGIN
			EXEC @r = dbo.LOAN_SP_LOAN_CLONE_SCHEDULE @loan_id = @loan_id 
			IF @@ERROR <> 0 OR @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END	
		END
	END
END

SELECT @loan_end_date = END_DATE, @disburse_type = DISBURSE_TYPE
FROM dbo.LOANS (NOLOCK) WHERE LOAN_ID = @loan_id

SELECT @r = @@ROWCOUNT, @e = @@ERROR
IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

SELECT @calc_date=CALC_DATE, @prev_step=PREV_STEP
FROM dbo.LOAN_DETAILS WHERE LOAN_ID=@loan_id
IF NOT @op_type IN (SELECT [TYPE_ID] FROM dbo.LOAN_OP_TYPES (NOLOCK))
BEGIN
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END


IF @by_processing = 0
BEGIN
	EXEC @r = dbo.LOAN_SP_PROCESS_BEFORE_OP_ACCOUNTING
		@doc_rec_id			= @doc_rec_id OUTPUT,
		@op_id				= @op_id,
		@user_id			= @user_id,
		@doc_date			= @op_date,
		@by_processing		= @by_processing,
		@simulate			= 0
	IF @r <> 0 OR @@ERROR <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ ÏÐÄÒÀÝÉÉÓ ÁÖÙÀËÔÒÖËÉ ÀÓÀáÅÉÓÀÓ!',16,1) RETURN(1) END
END

IF @op_type = dbo.loan_const_op_approval()
BEGIN
	UPDATE dbo.LOANS
	SET [STATE] = dbo.loan_const_state_approved()
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	IF @credit_line_id IS NOT NULL 
	BEGIN
		UPDATE dbo.LOAN_CREDIT_LINES SET [STATE]  = dbo.loan_credit_line_const_state_approved()
		WHERE CREDIT_LINE_ID = @credit_line_id AND [STATE] < dbo.loan_credit_line_const_state_approved()

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END
		
	DELETE dbo.LOAN_ACCOUNT_BALANCE
	WHERE LOAN_ID = @loan_id
	SET  @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_ACCOUNT_BALANCE (LOAN_ID)
	VALUES (@loan_id)
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	
	EXEC easy.on_user_after_op_approval
		@loan_id = @loan_id,
		@op_id = @op_id,
	    @user_id = @user_id

	EXEC easy.effr_CreateEffectiveRate
		@loan_id = @loan_id,
		@op_id = @op_id,
		@date = @op_date

	GOTO end_op
END

DECLARE
	@level_id int
IF @op_type = dbo.loan_const_op_disburse()
BEGIN
	SELECT @level_id = LEVEL_ID, @nu_principal = LOAN_NU_PRINCIPAL - @amount
	FROM dbo.LOAN_VW_LOAN_OP_DISBURSE
	WHERE OP_ID = @op_id

	SET @max_category_level = @level_id
	IF @level_id = 1 SET @category_1 = @amount ELSE SET @category_1 = NULL
	IF @level_id = 2 SET @category_2 = @amount ELSE SET @category_2 = NULL
	IF @level_id = 3 SET @category_3 = @amount ELSE SET @category_3 = NULL
	IF @level_id = 4 SET @category_4 = @amount ELSE SET @category_4 = NULL
	IF @level_id = 5 SET @category_5 = @amount ELSE SET @category_5 = NULL

	INSERT INTO dbo.LOAN_DETAILS(LOAN_ID, CALC_DATE, PREV_STEP, NU_PRINCIPAL, PRINCIPAL, MAX_CATEGORY_LEVEL, CATEGORY_1, CATEGORY_2, CATEGORY_3, CATEGORY_4, CATEGORY_5)
	VALUES(@loan_id, @op_date, @op_date, CASE WHEN ISNULL(@nu_principal, $0.00) > $0.00 THEN @nu_principal ELSE NULL END, @amount, @level_id, @category_1, @category_2, @category_3, @category_4, @category_5)
    IF @@ERROR <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	IF @update_data = 1
	BEGIN 
		UPDATE dbo.LOANS
		SET 
			[STATE]	= dbo.loan_const_state_current(),
			PAYMENT_DAY = V.NEW_PAYMENT_DAY,
			[START_DATE] = V.NEW_START_DATE,
			PERIOD = V.NEW_PERIOD,
			END_DATE = V.NEW_END_DATE,
			PMT = V.PMT,
			GRACE_FINISH_DATE = V.GRACE_FINISH_DATE
		FROM dbo.LOANS L (ROWLOCK) 
			INNER JOIN dbo.LOAN_VW_LOAN_OP_DISBURSE V ON L.LOAN_ID = V.LOAN_ID
		WHERE OP_ID = @op_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END


	IF @disburse_type = 4 -- ÒÏÝÀ ËÉÌÉÔÄÁÉÀ UPDATE_SCHEDULE ÜÀÒÈÖËÉÀ ÀÒÀÀ ÃÀ ÀÌÉÔÏÌ ÐÒÏÝÄÃÖÒÀ ÃÀÓÀßÚÉÓÛÉ ÀÒ ÃÀÀÊËÏÍÉÒÄÁÓ
	BEGIN
		EXEC @r = dbo.LOAN_SP_LOAN_CLONE_SCHEDULE @loan_id = @loan_id 
		IF @@ERROR <> 0 OR @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END	
	END

	IF @credit_line_id IS NOT NULL
	BEGIN
		UPDATE dbo.LOAN_CREDIT_LINES SET [STATE]  = dbo.loan_credit_line_const_state_current()
		WHERE CREDIT_LINE_ID = @credit_line_id AND [STATE] < dbo.loan_credit_line_const_state_current()

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END
	
	EXEC easy.effr_CreateEffectiveRate
		@loan_id = @loan_id,
		@op_id = @op_id,
		@date = @op_date

	GOTO end_op
END
 

IF @op_type = dbo.loan_const_op_disburse_transh()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	SELECT 
		@level_id = LEVEL_ID,
		@interest_transh_corrected = ISNULL(INTEREST_CORRECTION, $0.00),
		@nu_interest_transh_corrected  = ISNULL(NU_INTEREST_CORRECTION, $0.00),
		@pmt = PMT
	FROM dbo.LOAN_VW_LOAN_OP_DISBURSE_TRANSH 
	WHERE OP_ID = @op_id

	SET @max_category_level = @level_id

	IF @level_id = 1 SET @category_1 = @amount ELSE SET @category_1 = NULL
	IF @level_id = 2 SET @category_2 = @amount ELSE SET @category_2 = NULL
	IF @level_id = 3 SET @category_3 = @amount ELSE SET @category_3 = NULL
	IF @level_id = 4 SET @category_4 = @amount ELSE SET @category_4 = NULL
	IF @level_id = 5 SET @category_5 = @amount ELSE SET @category_5 = NULL

	SELECT @principal = ISNULL(PRINCIPAL, $0.00), @nu_principal = ISNULL(NU_PRINCIPAL, $0.00)
	FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id

	SET @principal = @principal + @amount
	SET @nu_principal = @nu_principal - @amount

	UPDATE dbo.LOAN_DETAILS 
	SET 
		PRINCIPAL = ISNULL(PRINCIPAL, $0.00) + @amount, 
		NU_PRINCIPAL = ISNULL(NU_PRINCIPAL, $0.00) - @amount,
		MAX_CATEGORY_LEVEL = CASE WHEN MAX_CATEGORY_LEVEL < @max_category_level THEN @max_category_level ELSE MAX_CATEGORY_LEVEL END, 
		
		CATEGORY_1 = CASE WHEN CATEGORY_1 IS NULL THEN @category_1 ELSE CATEGORY_1 + ISNULL(@category_1, $0.00) END,
		CATEGORY_2 = CASE WHEN CATEGORY_2 IS NULL THEN @category_2 ELSE CATEGORY_2 + ISNULL(@category_2, $0.00) END,
		CATEGORY_3 = CASE WHEN CATEGORY_3 IS NULL THEN @category_3 ELSE CATEGORY_3 + ISNULL(@category_3, $0.00) END,
		CATEGORY_4 = CASE WHEN CATEGORY_4 IS NULL THEN @category_4 ELSE CATEGORY_4 + ISNULL(@category_4, $0.00) END,
		CATEGORY_5 = CASE WHEN CATEGORY_5 IS NULL THEN @category_5 ELSE CATEGORY_5 + ISNULL(@category_5, $0.00) END
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SELECT @sched_date_after_transh = MIN(SCHEDULE_DATE) 
	FROM dbo.LOAN_SCHEDULE
	WHERE LOAN_ID = @loan_id AND @op_date <= SCHEDULE_DATE AND ORIGINAL_AMOUNT IS NOT NULL AND 
		((AMOUNT > $0.00) OR @disburse_type = 4) -- tu revolvirebadia AMOUNT = 0 yoveltvis

	IF @op_date = @sched_date_after_transh
		GOTO end_op

	UPDATE dbo.LOAN_DETAILS 
	SET 
		PREV_STEP = @op_date 
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	UPDATE dbo.LOANS
	SET PMT = @pmt
	WHERE LOAN_ID = @loan_id AND @pmt IS NOT NULL

	SET @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_late()
BEGIN
	UPDATE dbo.LOANS
	SET [STATE] = dbo.loan_const_state_lated()  
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, dbo.loan_const_op_late())
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SET @note_rec_id = @@IDENTITY

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_overdue()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOANS
	SET [STATE] = dbo.loan_const_state_overdued()
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, dbo.loan_const_op_overdue())
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SET @note_rec_id = @@IDENTITY

	GOTO end_op
END

DECLARE
	@overdue_op_amount money

IF @op_type = dbo.loan_const_op_overdue_revert()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)
	SET @op_ext_xml_2 = 
		(SELECT [LOAN_ID],[OVERDUE_DATE],[LATE_OP_ID],[OVERDUE_OP_ID],[OVERDUE_PRINCIPAL],[OVERDUE_PERCENT] FROM dbo.LOAN_DETAIL_OVERDUE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, dbo.loan_const_op_overdue_revert())
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SELECT @overdue_op_amount = AMOUNT FROM dbo.LOAN_OPS 
	WHERE OP_ID = @op_id

	UPDATE dbo.LOAN_DETAILS
	SET 
		PRINCIPAL = ISNULL(PRINCIPAL, $0.00) + @overdue_op_amount,
		OVERDUE_PRINCIPAL = NULL
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	UPDATE dbo.LOAN_DETAIL_OVERDUE
	SET
		OVERDUE_PRINCIPAL = $0.00
	WHERE LOAN_ID = @loan_id

	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	SET @note_rec_id = @@IDENTITY

	IF dbo.LOAN_FN_LOAN_HAS_ILLEGAL_DEBT (@loan_id) = 0
	BEGIN
		UPDATE dbo.LOAN_DETAILS
		SET 
			LATE_DATE = NULL, 
			OVERDUE_DATE = NULL
		WHERE LOAN_ID = @loan_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

		UPDATE dbo.LOANS
			SET [STATE] = dbo.loan_const_state_current()
		WHERE LOAN_ID = @loan_id	
	END

	GOTO end_op
END


DECLARE
	@schedule_date smalldatetime

IF @op_type = dbo.loan_const_op_stop_disburse()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

--	SELECT @nu_interest_correction  = ISNULL(NU_INTEREST, $0.00)
--	FROM dbo.LOAN_VW_LOAN_OP_STOP_DISBURSE
--	WHERE OP_ID = @op_id

	UPDATE dbo.LOAN_DETAILS 
	SET 
		--PREV_STEP = @op_date, 
		NU_PRINCIPAL = $0.00
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

DECLARE
	@dec_nu_amount money
IF @op_type = dbo.loan_const_op_dec_disburse()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	SELECT @dec_nu_amount  = ISNULL(DEC_AMOUNT, $0.00)
	FROM dbo.LOAN_VW_LOAN_OP_DEC_DISBURSE
	WHERE OP_ID = @op_id

	UPDATE dbo.LOAN_DETAILS 
	SET 
		NU_PRINCIPAL = @dec_nu_amount
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

DECLARE
	@balance money,
	@next_sched_date smalldatetime,
	@next_second_sched_date smalldatetime

IF @op_type = dbo.loan_const_op_payment()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	IF @by_processing = 1 GOTO end_op

--	SELECT @payment_type = PAYMENT_TYPE 
--	FROM LOAN_VW_LOAN_OP_PAYMENT WHERE OP_ID = @op_id
	SET @payment_type = 0

	SELECT 
		@overdue_percent_penalty = ISNULL(OVERDUE_PERCENT_PENALTY, $0.00), 
		@overdue_principal_penalty = ISNULL(OVERDUE_PRINCIPAL_PENALTY, $0.00), 
		@overdue_percent = ISNULL(OVERDUE_PERCENT, $0.00),
		@late_percent = ISNULL(LATE_PERCENT, $0.00), 
		@overdue_principal = ISNULL(OVERDUE_PRINCIPAL, $0.00), 
		@late_principal = ISNULL(LATE_PRINCIPAL, $0.00), 
		@overdue_principal_interest = ISNULL(OVERDUE_PRINCIPAL_INTEREST, $0.00),
		@interest = ISNULL(INTEREST, $0.00), 
		@nu_interest = ISNULL(NU_INTEREST, $0.00), 
		@principal = ISNULL(PRINCIPAL, $0.00),
		@prepayment = $0.00, --ISNULL(PREPAYMENT, $0.00),
		@prepayment_penalty = ISNULL(PREPAYMENT_PENALTY, $0.00),
		@overdue_insurance = ISNULL(OVERDUE_INSURANCE, $0.00),
		@overdue_service_fee = ISNULL(OVERDUE_SERVICE_FEE, $0.00),
		@defered_interest = ISNULL(DEFERED_INTEREST, $0.00),
		@defered_overdue_interest = ISNULL(DEFERED_OVERDUE_INTEREST, $0.00),
		@defered_penalty = ISNULL(DEFERED_PENALTY, $0.00),
		@defered_fine = ISNULL(DEFERED_FINE, $0.00)
	FROM dbo.LOAN_VW_LOAN_OP_PAYMENT_DETAILS 
	WHERE OP_ID = @op_id

	SELECT
		@principal_ = PRINCIPAL,
		@late_principal_ = LATE_PRINCIPAL,
		@overdue_principal_ = OVERDUE_PRINCIPAL,
		@max_category_level_ = MAX_CATEGORY_LEVEL, 
		@category_1	= CATEGORY_1,
		@category_2	= CATEGORY_2,
		@category_3	= CATEGORY_3,
		@category_4	= CATEGORY_4,
		@category_5	= CATEGORY_5
	FROM dbo.LOAN_DETAILS
	WHERE LOAN_ID = @loan_id

	SET @op_ext_xml_1 =
		(SELECT [LOAN_ID],[LATE_DATE],[LATE_OP_ID],[LATE_PRINCIPAL],[LATE_PERCENT] FROM dbo.LOAN_DETAIL_LATE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)

	SET @tmp_1_1 = @late_principal
	SET @tmp_2_1 = @late_percent

	UPDATE dbo.LOAN_DETAIL_LATE
	SET
		@tmp_1_2 = @tmp_1_1,
		@tmp_1_1 = CASE WHEN @tmp_1_1 > LATE_PRINCIPAL THEN @tmp_1_1 - LATE_PRINCIPAL ELSE $0.00 END,
		LATE_PRINCIPAL = CASE WHEN @tmp_1_1 > 0 THEN $0.00 ELSE LATE_PRINCIPAL - @tmp_1_2 END,
		@tmp_2_2 = @tmp_2_1,
		@tmp_2_1 = CASE WHEN @tmp_2_1 > LATE_PERCENT THEN @tmp_2_1 - LATE_PERCENT ELSE $0.00 END,
		LATE_PERCENT = CASE WHEN @tmp_2_1 > 0 THEN $0.00 ELSE LATE_PERCENT - @tmp_2_2 END
	WHERE LOAN_ID = @loan_id
	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END


	SET @op_ext_xml_2 =
		(SELECT [LOAN_ID],[OVERDUE_DATE],[LATE_OP_ID],[OVERDUE_OP_ID],[OVERDUE_PRINCIPAL],[OVERDUE_PERCENT] FROM dbo.LOAN_DETAIL_OVERDUE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)
	SET @tmp_1_1 = @overdue_principal
	SET @tmp_2_1 = @overdue_percent

	UPDATE dbo.LOAN_DETAIL_OVERDUE
	SET
		@tmp_1_2 = @tmp_1_1,
		@tmp_1_1 = CASE WHEN @tmp_1_1 > OVERDUE_PRINCIPAL THEN @tmp_1_1 - OVERDUE_PRINCIPAL ELSE $0.00 END,
		OVERDUE_PRINCIPAL = CASE WHEN @tmp_1_1 > 0 THEN $0.00 ELSE OVERDUE_PRINCIPAL - @tmp_1_2 END,
		@tmp_2_2 = @tmp_2_1,
		@tmp_2_1 = CASE WHEN @tmp_2_1 > OVERDUE_PERCENT THEN @tmp_2_1 - OVERDUE_PERCENT ELSE $0.00 END,
		OVERDUE_PERCENT = CASE WHEN @tmp_2_1 > 0 THEN $0.00 ELSE OVERDUE_PERCENT - @tmp_2_2 END
	WHERE LOAN_ID = @loan_id
	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	SET @overdue_date = NULL
	SELECT @overdue_date = MIN(OVERDUE_DATE)
	FROM dbo.LOAN_DETAIL_OVERDUE 
	WHERE (LOAN_ID = @loan_id) AND (ISNULL(OVERDUE_PRINCIPAL, $0.00) + ISNULL(OVERDUE_PERCENT, $0.00) <> $0.00)
		
	DECLARE
		@payed_principal money

	SET @payed_principal = @overdue_principal + @late_principal + @principal + @prepayment

	SET @max_category_level = 5

	IF ISNULL(@category_5, $0.00) > $0.00
	BEGIN
		IF ISNULL(@category_5, $0.00) > @payed_principal
		BEGIN
			SET @category_5 = @category_5 - @payed_principal
			SET @payed_principal = $0.00 
		END
		ELSE
		BEGIN
			SET @payed_principal = @payed_principal - @category_5
			SET @category_5 = $0.00
			IF @max_category_level_ <> 6
				SET @max_category_level = 4
		END
	END
	ELSE
		SET @max_category_level = 4

	IF ISNULL(@category_4, $0.00) > $0.00
	BEGIN
		IF ISNULL(@category_4, $0.00) > @payed_principal
		BEGIN
			SET @category_4 = @category_4 - @payed_principal
			SET @payed_principal = $0.00 
		END
		ELSE
		BEGIN
			SET @payed_principal = @payed_principal - @category_4
			SET @category_4 = $0.00 
			SET @max_category_level = 3
		END
	END 
	ELSE
		SET @max_category_level = 3

	IF ISNULL(@category_3, $0.00) > $0.00
	BEGIN
		IF ISNULL(@category_3, $0.00) > @payed_principal
		BEGIN
			SET @category_3 = @category_3 - @payed_principal
			SET @payed_principal = $0.00 
		END
		ELSE
		BEGIN
			SET @payed_principal = @payed_principal - @category_3
			SET @category_3 = $0.00
			SET @max_category_level = 2 
		END
	END 
	ELSE
		SET @max_category_level = 2


	IF ISNULL(@category_2, $0.00) > $0.00
	BEGIN
		IF ISNULL(@category_2, $0.00) > @payed_principal
		BEGIN
			SET @category_2 = @category_2 - @payed_principal
			SET @payed_principal = $0.00 
		END
		ELSE
		BEGIN
			SET @payed_principal = @payed_principal - @category_2
			SET @category_2 = $0.00 
			IF @max_category_level_ > 1
				SET @max_category_level = 2
			ELSE
				SET @max_category_level = 1
		END
	END 
	ELSE
		IF @max_category_level_ > 1
			SET @max_category_level = 2
		ELSE
			SET @max_category_level = 1


	IF ISNULL(@category_1, $0.00) > $0.00
	BEGIN
		IF ISNULL(@category_1, $0.00) > @payed_principal
		BEGIN
			SET @category_1 = @category_1 - @payed_principal
			SET @payed_principal = $0.00 
		END
		ELSE
		BEGIN
			SET @payed_principal = @payed_principal - @category_1
			SET @category_1 = $0.00 
		END
	END 


	UPDATE LOAN_DETAILS
	SET
		OVERDUE_PERCENT_PENALTY = OVERDUE_PERCENT_PENALTY - @overdue_percent_penalty,
		OVERDUE_PRINCIPAL_PENALTY = OVERDUE_PRINCIPAL_PENALTY - @overdue_principal_penalty,
		OVERDUE_PERCENT = OVERDUE_PERCENT - @overdue_percent,
		LATE_PERCENT = LATE_PERCENT - @late_percent,  
		OVERDUE_DATE = @overdue_date,
		OVERDUE_PRINCIPAL = OVERDUE_PRINCIPAL - @overdue_principal, 
		LATE_PRINCIPAL = LATE_PRINCIPAL - @late_principal, 
		OVERDUE_PRINCIPAL_INTEREST = OVERDUE_PRINCIPAL_INTEREST - @overdue_principal_interest,
		INTEREST = INTEREST - @interest, 
		NU_INTEREST = NU_INTEREST - @nu_interest, 
		PRINCIPAL = PRINCIPAL - @principal - @prepayment,
		NU_PRINCIPAL = CASE WHEN @disburse_type = 4 THEN ISNULL(NU_PRINCIPAL, $0.00) + (@principal + @prepayment + @late_principal + @overdue_principal) ELSE NU_PRINCIPAL END,
		PREV_STEP = CASE WHEN @interest + @nu_interest + @principal + @prepayment > $0.00 THEN @op_date ELSE PREV_STEP END,
		MAX_CATEGORY_LEVEL = @max_category_level,
		CATEGORY_1 = @category_1,
		CATEGORY_2 = @category_2,
		CATEGORY_3 = @category_3,
		CATEGORY_4 = @category_4,
		CATEGORY_5 = @category_5,
		OVERDUE_INSURANCE = OVERDUE_INSURANCE - @overdue_insurance,
		OVERDUE_SERVICE_FEE = OVERDUE_SERVICE_FEE - @overdue_service_fee,
		DEFERABLE_INTEREST = DEFERABLE_INTEREST - @defered_interest,
		DEFERABLE_OVERDUE_INTEREST = DEFERABLE_OVERDUE_INTEREST - @defered_overdue_interest,
		DEFERABLE_PENALTY = DEFERABLE_PENALTY - @defered_penalty,
		DEFERABLE_FINE = DEFERABLE_FINE - @defered_fine
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	IF (SELECT [STATE] FROM dbo.LOANS WHERE LOAN_ID = @loan_id) IN (dbo.loan_const_state_lated(), dbo.loan_const_state_overdued()) AND 
				dbo.LOAN_FN_LOAN_HAS_ILLEGAL_DEBT (@loan_id) = 0
	BEGIN
		UPDATE dbo.LOANS 
			SET [STATE] = dbo.loan_const_state_current()
		WHERE LOAN_ID = @loan_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END


		UPDATE dbo.LOAN_DETAILS 
			SET LATE_DATE = NULL, OVERDUE_DATE = NULL
		WHERE LOAN_ID = @loan_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_payment_writedoff()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	IF @by_processing = 1 GOTO end_op

	SELECT 
		@writeoff_principal = ISNULL(WRITEOFF_PRINCIPAL, $0.00),
		@writeoff_percent = ISNULL(WRITEOFF_PERCENT, $0.00),
		@writeoff_penalty = ISNULL(WRITEOFF_PENALTY, $0.00),
		@writeoff_principal_penalty = ISNULL(WRITEOFF_PRINCIPAL_PENALTY, $0.00),
		@writeoff_percent_penalty = ISNULL(WRITEOFF_PERCENT_PENALTY, $0.00)
	FROM dbo.LOAN_VW_LOAN_OP_PAYMENT_WRITEDOFF
	WHERE OP_ID = @op_id

	UPDATE LOAN_DETAILS
	SET
		WRITEOFF_PERCENT_PENALTY = WRITEOFF_PERCENT_PENALTY - @writeoff_percent_penalty,
		WRITEOFF_PRINCIPAL_PENALTY = WRITEOFF_PRINCIPAL_PENALTY - @writeoff_principal_penalty,
		WRITEOFF_PENALTY = WRITEOFF_PENALTY - @writeoff_penalty,
		WRITEOFF_PERCENT = WRITEOFF_PERCENT - @writeoff_percent,
		WRITEOFF_PRINCIPAL = WRITEOFF_PRINCIPAL - @writeoff_principal,
		CATEGORY_6 = CATEGORY_6 - ISNULL(@writeoff_principal, $0.00)
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	IF dbo.LOAN_FN_LOAN_HAS_ILLEGAL_DEBT (@loan_id) = 0
	BEGIN
		UPDATE dbo.LOANS
			SET [STATE] = dbo.loan_const_state_current()
		WHERE LOAN_ID = @loan_id	
	END
END

IF @op_type = dbo.loan_const_op_writedoff_forgive()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOAN_DETAILS 
	SET 
		WRITEOFF_PERCENT_PENALTY = V.WRITEOFF_PERCENT_PENALTY,
		WRITEOFF_PRINCIPAL_PENALTY = V.WRITEOFF_PRINCIPAL_PENALTY,
		WRITEOFF_PENALTY = V.WRITEOFF_PENALTY,
		WRITEOFF_PERCENT = V.WRITEOFF_PERCENT,
		WRITEOFF_PRINCIPAL = V.WRITEOFF_PRINCIPAL,
		CATEGORY_6 = CATEGORY_6 - (V.WRITEOFF_PRINCIPAL_ORG - V.WRITEOFF_PRINCIPAL)
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_WRITEDOFF_FORGIVE V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type IN (dbo.loan_const_op_restructure(), dbo.loan_const_op_loan_correct(), dbo.loan_const_op_loan_correct2())
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE loans
	SET
		INTRATE = V.INTRATE,
		PENALTY_INTRATE = V.PENALTY_INTRATE,
		NOTUSED_INTRATE = V.NOTUSED_INTRATE,
		PREPAYMENT_INTRATE = V.PREPAYMENT_INTRATE,
		PAYMENT_DAY = V.PAYMENT_DAY,
		PAYMENT_INTERVAL_TYPE = V.PAYMENT_INTERVAL_TYPE,
		SCHEDULE_TYPE = V.SCHEDULE_TYPE,
		GRACE_TYPE = V.GRACE_TYPE,
		GRACE_STEPS = V.GRACE_STEPS,
		GRACE_FINISH_DATE = V.GRACE_FINISH_DATE,
		PMT = V.PMT,
		RESTRUCTURED = RESTRUCTURED + CASE WHEN @op_type = dbo.loan_const_op_restructure() THEN 1 ELSE 0 END
	FROM dbo.LOANS loans
		INNER JOIN dbo.LOAN_VW_LOAN_OP_RESTRUCTURE V ON loans.LOAN_ID = V.LOAN_ID
	WHERE V.OP_ID = @op_id


	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_restructure_params()
BEGIN
	UPDATE loans
	SET
		PURPOSE_TYPE = V.PURPOSE_TYPE,
		GROUP_ID = V.GROUP_ID,
		CORESPONSIBLE_USER_ID = V.CORESPONSIBLE_USER_ID,
		PREPAYMENT_STEP = V.PREPAYMENT_STEP,
		INTEREST_FLAGS = V.INTEREST_FLAGS,
		PREPAYMENT_FLAGS = V.PREPAYMENT_FLAGS,
		RESERVE_MAX_CATEGORY = V.RESERVE_MAX_CATEGORY
	FROM dbo.LOANS loans
		INNER JOIN dbo.LOAN_VW_LOAN_OP_RESTRUCTURE_PARAMS V ON loans.LOAN_ID = V.LOAN_ID
	WHERE V.OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_restructure_schedule()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	SELECT 
		@interest_correction = INTEREST,
		@nu_interest_correction = NU_INTEREST,
		@pmt = PMT
	FROM dbo.LOAN_VW_LOAN_OP_RESTRUCTURE_SCHEDULE WHERE OP_ID = @op_id

	UPDATE dbo.LOAN_SCHEDULE 
	SET INTEREST_CORRECTION = @interest_correction,
		NU_INTEREST_CORRECTION = @nu_interest_correction
	WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE = (SELECT MIN(SCHEDULE_DATE) FROM dbo.LOAN_SCHEDULE  WHERE LOAN_ID = @loan_id)

	UPDATE dbo.LOANS
	SET PMT = @pmt
	WHERE LOAN_ID = @loan_id AND @pmt IS NOT NULL

	SET @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
END

IF @op_type = dbo.loan_const_op_prolongation()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)
	DECLARE
		@new_end_date smalldatetime,
		@new_period int

	SELECT 
		@new_end_date = NEW_END_DATE,
		@new_period = PROLONGED_PERIOD,
		@pmt = PMT
	FROM dbo.LOAN_VW_LOAN_OP_PROLONG
	WHERE OP_ID = @op_id	

	UPDATE dbo.LOANS 
	SET
		END_DATE = @new_end_date,
		PERIOD = @new_period,
		PROLONGED = PROLONGED + 1,
		PMT = CASE WHEN @pmt IS NULL THEN PMT ELSE @pmt END
	WHERE LOAN_ID = @loan_id					 
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, @op_type)
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SET @note_rec_id = @@IDENTITY
	
	--EXEC @r = dbo.LOAN_SP_LOAN_CLONE_SCHEDULE @loan_id = @loan_id 
	--IF @r <> 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_penalty_stop() 
BEGIN
	SELECT @penalty_flags = NEW_PENALTY_FLAGS FROM dbo.LOAN_VW_LOAN_OP_PENALTY_STOP WHERE OP_ID = @op_id

	UPDATE dbo.LOANS
	SET	PENALTY_FLAGS = @penalty_flags
	WHERE LOAN_ID = @loan_id
	
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END
 
IF @op_type = dbo.loan_const_op_officer_change()
BEGIN
	SELECT @new_resp_user_id = NEW_RESPONSIBLE_USER_ID FROM dbo.LOAN_VW_LOAN_OP_OFFICER_CHANGE
	WHERE OP_ID = @op_id

	UPDATE dbo.LOANS
	SET	RESPONSIBLE_USER_ID = @new_resp_user_id 
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_penalty_forgive()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

 	UPDATE dbo.LOAN_DETAILS 
	SET 
		OVERDUE_PRINCIPAL_PENALTY = V.OVERDUE_PRINCIPAL_PENALTY,
		OVERDUE_PERCENT_PENALTY = V.OVERDUE_PERCENT_PENALTY,
		CALLOFF_PRINCIPAL_PENALTY = V.CALLOFF_PRINCIPAL_PENALTY,
		CALLOFF_PERCENT_PENALTY = V.CALLOFF_PERCENT_PENALTY,
		WRITEOFF_PRINCIPAL_PENALTY = V.WRITEOFF_PRINCIPAL_PENALTY,
		WRITEOFF_PERCENT_PENALTY = V.WRITEOFF_PERCENT_PENALTY 
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_PENALTY_FORGIVE V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	IF dbo.LOAN_FN_LOAN_HAS_ILLEGAL_DEBT (@loan_id) = 0
	BEGIN
		UPDATE dbo.LOANS
			SET [STATE] = dbo.loan_const_state_current()
		WHERE LOAN_ID = @loan_id	
	END

	GOTO end_op
END

DECLARE
	@def_penalty money
IF @op_type = dbo.loan_const_op_debt_defere()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

 	UPDATE dbo.LOAN_DETAILS 
	SET
		INTEREST = INTEREST - V.DEF_INTEREST,
		OVERDUE_PERCENT = ISNULL(OVERDUE_PERCENT, $0.00) - V.DEF_OVERDUE_INTEREST,
		OVERDUE_PRINCIPAL_PENALTY = CASE WHEN ISNULL(OVERDUE_PERCENT_PENALTY, $0.00) < V.DEF_PENALTY THEN ISNULL(OVERDUE_PRINCIPAL_PENALTY, $0.00) + ISNULL(OVERDUE_PERCENT_PENALTY, $0.00) - V.DEF_PENALTY ELSE OVERDUE_PRINCIPAL_PENALTY END,
		OVERDUE_PERCENT_PENALTY = CASE WHEN ISNULL(OVERDUE_PERCENT_PENALTY, $0.00) > V.DEF_PENALTY THEN ISNULL(OVERDUE_PERCENT_PENALTY, $0.00) - V.DEF_PENALTY ELSE $0.00 END,
		FINE = FINE - V.DEF_FINE,
		
		DEFERABLE_INTEREST = ISNULL(DEFERABLE_INTEREST, $0.00) + V.DEF_INTEREST,
		DEFERABLE_OVERDUE_INTEREST = ISNULL(DEFERABLE_OVERDUE_INTEREST, $0.00) + V.DEF_OVERDUE_INTEREST,
		DEFERABLE_PENALTY = ISNULL(DEFERABLE_PENALTY, $0.00) + V.DEF_PENALTY,
		DEFERABLE_FINE = ISNULL(DEFERABLE_FINE, $0.00) + V.DEF_FINE
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_DEFERE_DEBT V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

DECLARE 
	@fine_amount money
IF @op_type = dbo.loan_const_op_fine_accrue()
BEGIN 
	SELECT @fine_amount = AMOUNT FROM dbo.LOAN_OPS
	WHERE OP_ID = @op_id
	
 	UPDATE dbo.LOAN_DETAILS 
	SET 
		FINE = ISNULL(FINE, $0.00) + @fine_amount
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_fine_forgive()
BEGIN 
	SELECT @fine_amount = AMOUNT FROM dbo.LOAN_OPS
	WHERE OP_ID = @op_id
	
 	UPDATE dbo.LOAN_DETAILS 
	SET 
		FINE = FINE - @fine_amount
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_restructure_risks()
BEGIN
	SET @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOAN_DETAILS
	SET 
		CATEGORY_1 = CASE WHEN V.NEW_CATEGORY_1 = $0.00 THEN NULL ELSE V.NEW_CATEGORY_1 END,
		CATEGORY_2 = CASE WHEN V.NEW_CATEGORY_2 = $0.00 THEN NULL ELSE V.NEW_CATEGORY_2 END,
		CATEGORY_3 = CASE WHEN V.NEW_CATEGORY_3 = $0.00 THEN NULL ELSE V.NEW_CATEGORY_3 END,
		CATEGORY_4 = CASE WHEN V.NEW_CATEGORY_4 = $0.00 THEN NULL ELSE V.NEW_CATEGORY_4 END,
		CATEGORY_5 = CASE WHEN V.NEW_CATEGORY_5 = $0.00 THEN NULL ELSE V.NEW_CATEGORY_5 END,
		MAX_CATEGORY_LEVEL = CASE
			WHEN V.NEW_CATEGORY_5 <> $0.00 THEN 5
			WHEN V.NEW_CATEGORY_4 <> $0.00 THEN 4
			WHEN V.NEW_CATEGORY_3 <> $0.00 THEN 3
			WHEN V.NEW_CATEGORY_2 <> $0.00 THEN 2
			WHEN V.NEW_CATEGORY_1 <> $0.00 THEN 1
			ELSE 1
		END
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_RESTRUCTURE_RISKS V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id


	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

IF @op_type = dbo.loan_const_op_individual_risks()
BEGIN
	UPDATE dbo.LOANS
	SET 
		RISK_TYPE = V.NEW_RISK_TYPE,	
		RISK_PERC_RATE_1 = V.RISK_PERC_RATE_NEW_1,
		RISK_PERC_RATE_2 = V.RISK_PERC_RATE_NEW_2,
		RISK_PERC_RATE_3 = V.RISK_PERC_RATE_NEW_3,
		RISK_PERC_RATE_4 = V.RISK_PERC_RATE_NEW_4,
		RISK_PERC_RATE_5 = V.RISK_PERC_RATE_NEW_5
	FROM dbo.LOANS L (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_INDIVIDUAL_RISKS V ON L.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

IF @op_type IN (dbo.loan_const_op_close(), dbo.loan_const_op_guar_close())
BEGIN
	DECLARE
		@collat_list varchar(1000),
		@close_collat bit
		
	SET @collat_list = ''
	
	IF @op_type = dbo.loan_const_op_close()
	BEGIN
		SELECT @close_collat = CLOSE_COLLAT, @collat_list = ISNULL(COLLATERAL_LIST, '') 
		FROM dbo.LOAN_VW_LOAN_OP_CLOSE WHERE OP_ID = @op_id
	END
	
	IF @op_type = dbo.loan_const_op_guar_close()
	BEGIN
		SELECT @close_collat = CLOSE_COLLAT, @collat_list = ISNULL(COLLATERAL_LIST, '') 
		FROM dbo.LOAN_VW_GUARANTEE_OP_CLOSE WHERE OP_ID = @op_id
	END
	
	IF (@close_collat = 1) AND (@collat_list <> '')
	BEGIN
		SET @op_ext_xml_1 =
			(SELECT C.COLLATERAL_ID, C.ISO, C.COLLATERAL_TYPE, C.AMOUNT, 0 AS IS_LINKED
			 FROM dbo.fn_split_list_int(@collat_list, ',') L
					INNER JOIN dbo.LOAN_COLLATERALS C (NOLOCK) ON L.ID = C.COLLATERAL_ID
 			 FOR XML RAW, ROOT)
 	END

	UPDATE dbo.LOANS
	SET [STATE] = dbo.loan_const_state_closed() --თუ სესხზე არ დარჩა დავალიანება მაშინ დავხუროთ  
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, @op_type)
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	SET @note_rec_id = @@IDENTITY

	IF @by_processing = 0
	BEGIN 
		INSERT INTO dbo.LOAN_DETAILS_HISTORY
		SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id
		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END

	DELETE FROM dbo.LOAN_DETAILS
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

IF @op_type = dbo.loan_const_op_writeoff()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	SET @op_ext_xml_1 =
		(SELECT [LOAN_ID],[LATE_DATE],[LATE_OP_ID],[LATE_PRINCIPAL],[LATE_PERCENT] FROM dbo.LOAN_DETAIL_LATE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)

	SELECT @tmp_1_1 = ISNULL(LATE_PRINCIPAL, $0.00), @tmp_2_1 = ISNULL(LATE_PERCENT, $0.00) FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id 

	UPDATE dbo.LOAN_DETAIL_LATE
	SET
		@tmp_1_2 = @tmp_1_1,
		@tmp_1_1 = CASE WHEN @tmp_1_1 > LATE_PRINCIPAL THEN @tmp_1_1 - LATE_PRINCIPAL ELSE $0.00 END,
		LATE_PRINCIPAL = CASE WHEN @tmp_1_1 > 0 THEN $0.00 ELSE LATE_PRINCIPAL - @tmp_1_2 END,
		@tmp_2_2 = @tmp_2_1,
		@tmp_2_1 = CASE WHEN @tmp_2_1 > LATE_PERCENT THEN @tmp_2_1 - LATE_PERCENT ELSE $0.00 END,
		LATE_PERCENT = CASE WHEN @tmp_2_1 > 0 THEN $0.00 ELSE LATE_PERCENT - @tmp_2_2 END
	WHERE LOAN_ID = @loan_id
	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	SET @op_ext_xml_2 =
		(SELECT [LOAN_ID],[OVERDUE_DATE],[LATE_OP_ID],[OVERDUE_OP_ID],[OVERDUE_PRINCIPAL],[OVERDUE_PERCENT] FROM dbo.LOAN_DETAIL_OVERDUE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)

	SELECT @tmp_1_1 = ISNULL(OVERDUE_PRINCIPAL, $0.00), @tmp_2_1 = ISNULL(OVERDUE_PERCENT, $0.00) FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id 

	UPDATE dbo.LOAN_DETAIL_OVERDUE
	SET
		@tmp_1_2 = @tmp_1_1,
		@tmp_1_1 = CASE WHEN @tmp_1_1 > OVERDUE_PRINCIPAL THEN @tmp_1_1 - OVERDUE_PRINCIPAL ELSE $0.00 END,
		OVERDUE_PRINCIPAL = CASE WHEN @tmp_1_1 > 0 THEN $0.00 ELSE OVERDUE_PRINCIPAL - @tmp_1_2 END,
		@tmp_2_2 = @tmp_2_1,
		@tmp_2_1 = CASE WHEN @tmp_2_1 > OVERDUE_PERCENT THEN @tmp_2_1 - OVERDUE_PERCENT ELSE $0.00 END,
		OVERDUE_PERCENT = CASE WHEN @tmp_2_1 > 0 THEN $0.00 ELSE OVERDUE_PERCENT - @tmp_2_2 END
	WHERE LOAN_ID = @loan_id
	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

 	UPDATE dbo.LOAN_DETAILS 
	SET 
		NU_PRINCIPAL = NULL, NU_INTEREST = NULL, NU_INTEREST_DAILY = NULL, NU_INTEREST_FRACTION = NULL,
		PRINCIPAL = NULL, INTEREST = NULL, INTEREST_DAILY = NULL, INTEREST_FRACTION = NULL,
		LATE_DATE = NULL, LATE_PRINCIPAL = NULL, LATE_PERCENT = NULL,
		OVERDUE_DATE = NULL, OVERDUE_PRINCIPAL = NULL, OVERDUE_PRINCIPAL_INTEREST = NULL, OVERDUE_PRINCIPAL_INTEREST_DAILY = NULL, OVERDUE_PRINCIPAL_INTEREST_FRACTION = NULL,
		OVERDUE_PRINCIPAL_PENALTY = NULL, OVERDUE_PRINCIPAL_PENALTY_DAILY = NULL, OVERDUE_PRINCIPAL_PENALTY_FRACTION = NULL,
		OVERDUE_PERCENT = NULL, OVERDUE_PERCENT_PENALTY = NULL, OVERDUE_PERCENT_PENALTY_DAILY = NULL, OVERDUE_PERCENT_PENALTY_FRACTION = NULL,
		CALLOFF_PRINCIPAL = NULL, CALLOFF_PRINCIPAL_INTEREST = NULL, CALLOFF_PRINCIPAL_INTEREST_DAILY = NULL, CALLOFF_PRINCIPAL_INTEREST_FRACTION = NULL, 
		CALLOFF_PRINCIPAL_PENALTY = NULL, CALLOFF_PRINCIPAL_PENALTY_DAILY = NULL, CALLOFF_PRINCIPAL_PENALTY_FRACTION = NULL,
		CALLOFF_PERCENT = NULL, CALLOFF_PERCENT_PENALTY = NULL, CALLOFF_PERCENT_PENALTY_DAILY = NULL, CALLOFF_PERCENT_PENALTY_FRACTION = NULL, CALLOFF_PENALTY = NULL,
		WRITEOFF_PRINCIPAL = V.OVERDUE_PRINCIPAL + V.LATE_PRINCIPAL + V.PRINCIPAL,
		WRITEOFF_PRINCIPAL_PENALTY = NULL,
		WRITEOFF_PERCENT = V.INTEREST + V.NU_INTEREST + V.OVERDUE_PRINCIPAL_INTEREST + V.OVERDUE_PERCENT + V.LATE_PERCENT,
		WRITEOFF_PERCENT_PENALTY = NULL,
		WRITEOFF_PENALTY = V.OVERDUE_PRINCIPAL_PENALTY + V.OVERDUE_PERCENT_PENALTY, 
		MAX_CATEGORY_LEVEL = 6,
		CATEGORY_1 = NULL,
		CATEGORY_2 = NULL,
		CATEGORY_3 = NULL,
		CATEGORY_4 = NULL,
		CATEGORY_5 = NULL,
		CATEGORY_6 = V.OVERDUE_PRINCIPAL + V.LATE_PRINCIPAL + V.PRINCIPAL
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_LOAN_OP_WRITEOFF_DETAILS V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SELECT @schedule_date = MIN(SCHEDULE_DATE) 
	FROM dbo.LOAN_SCHEDULE
	WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE >= @op_date AND ORIGINAL_AMOUNT IS NOT NULL AND 
		((AMOUNT > $0.00) OR @disburse_type = 4)

	IF @schedule_date IS NOT NULL
	BEGIN
		UPDATE dbo.LOAN_SCHEDULE
		SET 
			AMOUNT = $0.00,
			PRINCIPAL = $0.00,
			INTEREST = $0.00,
			NU_INTEREST = $0.00,
			BALANCE = $0.00
		WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE >= @schedule_date

		IF @@ERROR <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	END

	UPDATE dbo.LOANS
	SET [STATE] = dbo.loan_const_state_writedoff(),
		WRITEOFF_DATE = @op_date  
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	INSERT INTO dbo.LOAN_NOTES(LOAN_ID, [OWNER], OP_TYPE)
	VALUES(@loan_id, @user_id, dbo.loan_const_op_writeoff())
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SET @note_rec_id = @@IDENTITY

	GOTO end_op
END

IF @op_type IN (dbo.loan_const_op_restructure_collateral(), dbo.loan_const_op_correct_collateral())
BEGIN
	EXEC @r = dbo.LOAN_SP_RESTORE_OP_LOAN_COLLATERALS @op_id, @loan_id, @op_ext_xml_1 OUT
	IF @r <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
END

DECLARE
	@accrue_penalty money,
	@current_interest money
IF @op_type = dbo.loan_const_op_freeze()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	SELECT 
		@accrue_penalty = ROUND((ISNULL(PRINCIPAL, $0.00) + ISNULL(OVERDUE_PRINCIPAL, $0.00) + ISNULL(WRITEOFF_PRINCIPAL, $0.00)) * $0.12, 2),
		@current_interest = ISNULL(INTEREST, $0.00)
	FROM dbo.LOAN_DETAILS (NOLOCK)
	WHERE LOAN_ID = @loan_id

	UPDATE dbo.LOAN_DETAILS 
	SET OVERDUE_PRINCIPAL_PENALTY = ISNULL(OVERDUE_PRINCIPAL_PENALTY, $0.00) + @accrue_penalty
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	UPDATE dbo.LOANS 
	SET	PREPAYMENT_INTRATE = $0.00, PENALTY_FLAGS = 0
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	SELECT TOP 1 @next_sched_date = SCHEDULE_DATE 
	FROM dbo.LOAN_SCHEDULE (NOLOCK)
	WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE >= dbo.loan_open_date()
	ORDER BY SCHEDULE_DATE ASC

	IF @next_sched_date IS NOT NULL
	BEGIN
		UPDATE dbo.LOAN_SCHEDULE
		SET INTEREST = @current_interest, INTEREST_CORRECTION = @current_interest, AMOUNT = PRINCIPAL + @current_interest
		WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE = @next_sched_date

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

		UPDATE dbo.LOAN_SCHEDULE
		SET INTEREST = $0.00, AMOUNT = PRINCIPAL
		WHERE LOAN_ID = @loan_id AND SCHEDULE_DATE > @next_sched_date
	END
END


IF @op_type = dbo.loan_const_op_guar_disburse()
BEGIN
	SELECT 
		@level_id = LEVEL_ID, @remaining_fee = REMAINING_FEE
	FROM dbo.LOAN_VW_GUARANTEE_OP_DISBURSE
	WHERE OP_ID = @op_id

	SET @max_category_level = @level_id
	IF @level_id = 1 SET @category_1 = @amount ELSE SET @category_1 = NULL
	IF @level_id = 2 SET @category_2 = @amount ELSE SET @category_2 = NULL
	IF @level_id = 3 SET @category_3 = @amount ELSE SET @category_3 = NULL
	IF @level_id = 4 SET @category_4 = @amount ELSE SET @category_4 = NULL
	IF @level_id = 5 SET @category_5 = @amount ELSE SET @category_5 = NULL

	INSERT INTO dbo.LOAN_DETAILS(LOAN_ID, CALC_DATE, PREV_STEP, PRINCIPAL, MAX_CATEGORY_LEVEL, CATEGORY_1, CATEGORY_2, CATEGORY_3, CATEGORY_4, CATEGORY_5, REMAINING_FEE)
	VALUES(@loan_id, @op_date, @op_date, @amount, @level_id, @category_1, @category_2, @category_3, @category_4, @category_5, @remaining_fee)
    IF @@ERROR <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	IF @update_data = 1
	BEGIN 
		UPDATE dbo.LOANS
		SET 
			[STATE]	= dbo.loan_const_state_current(),
			PAYMENT_DAY = V.NEW_PAYMENT_DAY,
			[START_DATE] = V.NEW_START_DATE,
			PERIOD = V.NEW_PERIOD,
			END_DATE = V.NEW_END_DATE
		FROM dbo.LOANS L (ROWLOCK) 
			INNER JOIN dbo.LOAN_VW_GUARANTEE_OP_DISBURSE V ON L.LOAN_ID = V.LOAN_ID
		WHERE OP_ID = @op_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END

	IF @credit_line_id IS NOT NULL
	BEGIN
		UPDATE dbo.LOAN_CREDIT_LINES SET [STATE]  = dbo.loan_credit_line_const_state_current()
		WHERE CREDIT_LINE_ID = @credit_line_id AND [STATE] < dbo.loan_credit_line_const_state_current()

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_guar_payment()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	IF @by_processing = 1 GOTO end_op

	SET @payment_type = 0

	SELECT 
		@overdue_percent_penalty = ISNULL(PENALTY, $0.00), 
		@overdue_percent = ISNULL(OVERDUE_PERCENT, $0.00),
		@interest = ISNULL(INTEREST, $0.00)
	FROM dbo.LOAN_VW_GUARANTEE_OP_PAYMENT 
	WHERE OP_ID = @op_id

	SET @op_ext_xml_2 =
		(SELECT [LOAN_ID],[OVERDUE_DATE],[LATE_OP_ID],[OVERDUE_OP_ID],[OVERDUE_PRINCIPAL],[OVERDUE_PERCENT] FROM dbo.LOAN_DETAIL_OVERDUE WHERE LOAN_ID = @loan_id FOR XML RAW, ROOT)
	SET @tmp_2_1 = @overdue_percent

	UPDATE dbo.LOAN_DETAIL_OVERDUE
	SET
		@tmp_2_2 = @tmp_2_1,
		@tmp_2_1 = CASE WHEN @tmp_2_1 > OVERDUE_PERCENT THEN @tmp_2_1 - OVERDUE_PERCENT ELSE $0.00 END,
		OVERDUE_PERCENT = CASE WHEN @tmp_2_1 > 0 THEN $0.00 ELSE OVERDUE_PERCENT - @tmp_2_2 END
	WHERE LOAN_ID = @loan_id
	SELECT @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END

	SET @overdue_date = NULL
	SELECT @overdue_date = MIN(OVERDUE_DATE)
	FROM dbo.LOAN_DETAIL_OVERDUE 
	WHERE (LOAN_ID = @loan_id) AND (ISNULL(OVERDUE_PERCENT, $0.00) <> $0.00)

	UPDATE dbo.LOAN_DETAILS
	SET
		OVERDUE_PERCENT_PENALTY = OVERDUE_PERCENT_PENALTY - @overdue_percent_penalty,
		OVERDUE_PERCENT = OVERDUE_PERCENT - @overdue_percent,
		OVERDUE_DATE = @overdue_date,
		INTEREST = INTEREST - @interest
	WHERE LOAN_ID = @loan_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	IF (SELECT [STATE] FROM dbo.LOANS WHERE LOAN_ID = @loan_id) IN (dbo.loan_const_state_lated(), dbo.loan_const_state_overdued()) AND 
				dbo.LOAN_FN_LOAN_HAS_ILLEGAL_DEBT (@loan_id) = 0
	BEGIN
		UPDATE dbo.LOANS 
			SET [STATE] = dbo.loan_const_state_current()
		WHERE LOAN_ID = @loan_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END


		UPDATE dbo.LOAN_DETAILS 
			SET LATE_DATE = NULL, OVERDUE_DATE = NULL
		WHERE LOAN_ID = @loan_id

		SELECT @r = @@ROWCOUNT, @e = @@ERROR
		IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
		IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
	END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_guar_fee()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOAN_DETAILS
	SET 
		REMAINING_FEE = REMAINING_FEE - @amount
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END


	UPDATE LOAN_DETAILS
	SET 
		REMAINING_FEE = CASE WHEN REMAINING_FEE = $0.00 THEN NULL ELSE REMAINING_FEE END
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

	GOTO end_op
END

IF @op_type = dbo.loan_const_op_guar_inc()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOAN_DETAILS  --ÀÌ ÛÄÌÈáÅÄÅÀÛÉ ÐÒÉÍÝÉÐÛÉ ÒÉÓÊÄÁÉÓÈÅÉÓ ÐÉÒÃÀÐÉÒ ÞÉÒÉÓ ÌÉÍÉàÄÁÀÝ ÛÄÉÞËÄÁÏÃÀ 
	SET 
		PRINCIPAL = PRINCIPAL + ISNULL(V.AMOUNT_ADD, $0.00),
		CATEGORY_1 = CASE WHEN ISNULL(CATEGORY_1, $0.00) > $0.00 THEN CATEGORY_1 + ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_1 END,
		CATEGORY_2 = CASE WHEN ISNULL(CATEGORY_2, $0.00) > $0.00 THEN CATEGORY_2 + ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_2 END,
		CATEGORY_3 = CASE WHEN ISNULL(CATEGORY_3, $0.00) > $0.00 THEN CATEGORY_3 + ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_3 END,
		CATEGORY_4 = CASE WHEN ISNULL(CATEGORY_4, $0.00) > $0.00 THEN CATEGORY_4 + ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_4 END,
		CATEGORY_5 = CASE WHEN ISNULL(CATEGORY_5, $0.00) > $0.00 THEN CATEGORY_5 + ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_5 END
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_GUARANTEE_OP_INC V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

IF @op_type = dbo.loan_const_op_guar_dec()
BEGIN
	SELECT @op_loan_details = (SELECT * FROM dbo.LOAN_DETAILS WHERE LOAN_ID = @loan_id FOR XML RAW)

	UPDATE dbo.LOAN_DETAILS  --ÀÌ ÛÄÌÈáÅÄÅÀÛÉ ÐÒÉÍÝÉÐÛÉ ÒÉÓÊÄÁÉÓÈÅÉÓ ÐÉÒÃÀÐÉÒ ÞÉÒÉÓ ÌÉÍÉàÄÁÀÝ ÛÄÉÞËÄÁÏÃÀ 
	SET 
		PRINCIPAL = PRINCIPAL - ISNULL(V.AMOUNT_ADD, $0.00),
		CATEGORY_1 = CASE WHEN ISNULL(CATEGORY_1, $0.00) > $0.00 THEN CATEGORY_1 - ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_1 END,
		CATEGORY_2 = CASE WHEN ISNULL(CATEGORY_2, $0.00) > $0.00 THEN CATEGORY_2 - ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_2 END,
		CATEGORY_3 = CASE WHEN ISNULL(CATEGORY_3, $0.00) > $0.00 THEN CATEGORY_3 - ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_3 END,
		CATEGORY_4 = CASE WHEN ISNULL(CATEGORY_4, $0.00) > $0.00 THEN CATEGORY_4 - ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_4 END,
		CATEGORY_5 = CASE WHEN ISNULL(CATEGORY_5, $0.00) > $0.00 THEN CATEGORY_5 - ISNULL(V.AMOUNT_ADD, $0.00) ELSE CATEGORY_5 END
	FROM dbo.LOAN_DETAILS D (ROWLOCK) 
		INNER JOIN dbo.LOAN_VW_GUARANTEE_OP_INC V ON D.LOAN_ID = V.LOAN_ID
	WHERE OP_ID = @op_id

	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

end_op: 

UPDATE dbo.LOAN_OPS 
SET 
	OP_STATE = 0xFF, AUTH_OWNER=@user_id, BY_PROCESSING = @by_processing, 
	NOTE_REC_ID = @note_rec_id, OP_LOAN_DETAILS = @op_loan_details, OP_EXT_XML_1 = @op_ext_xml_1, OP_EXT_XML_2 = @op_ext_xml_2
WHERE OP_ID = @op_id
SELECT @r = @@ROWCOUNT, @e = @@ERROR
IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END

IF @update_data = 1
BEGIN
	UPDATE dbo.LOANS
	SET ROW_VERSION = ROW_VERSION + 1
	WHERE LOAN_ID = @loan_id
	SELECT @r = @@ROWCOUNT, @e = @@ERROR
	IF @e <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ.',16,1) RETURN(1) END
	IF @r = 0 BEGIN RAISERROR('RECORD NOT FOUND',16,1) RETURN(1) END
END

IF @update_schedule = 1 AND @op_type NOT IN (dbo.loan_const_op_payment(), dbo.loan_const_op_stop_disburse(), dbo.loan_const_op_freeze())
BEGIN
	UPDATE dbo.LOAN_DETAILS 
	SET 
		PREV_STEP = @op_date
	WHERE LOAN_ID = @loan_id
END

SET @doc_rec_id = NULL
	
EXEC @r = dbo.LOAN_SP_PROCESS_OP_ACCOUNTING
	@doc_rec_id			= @doc_rec_id OUTPUT,
	@op_id				= @op_id,
	@user_id			= @user_id,
	@doc_date			= @op_date,
	@by_processing		= @by_processing,
	@simulate			= 0
IF @r <> 0 OR @@ERROR <> 0 BEGIN RAISERROR ('ÛÄÝÃÏÌÀ ÏÐÄÒÀÝÉÉÓ ÁÖÙÀËÔÒÖËÉ ÀÓÀáÅÉÓÀÓ!',16,1) RETURN(1) END

RETURN 0
