SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE dbo.loan_process_overdue
	@loan_id							int,
	@date								smalldatetime,
	@op_commit							bit OUTPUT,
	@schedule_date						smalldatetime,
	@schedule_nu_interest				money OUTPUT,
	@schedule_interest					money OUTPUT,
	@schedule_principal					money OUTPUT,
	@schedule_insurance					money OUTPUT,
	@schedule_service_fee				money OUTPUT,
	@schedule_defered_interest			money OUTPUT,
	@schedule_defered_overdue_interest	money = NULL OUTPUT,
	@nu_interest						money OUTPUT,
	@interest							money OUTPUT,
	@principal							money OUTPUT,
	@deferable_interest					money OUTPUT,
	@deferable_overdue_interest			money = NULL OUTPUT,
	@overdue_percent					money OUTPUT,
	@overdue_principal					money OUTPUT,
	@step_overdue_percent				money OUTPUT,
	@step_overdue_principal				money OUTPUT,
	@overdue_insurance					money OUTPUT,
	@overdue_service_fee				money OUTPUT,
	@step_overdue_insurance				money OUTPUT,
	@step_overdue_service_fee			money OUTPUT,
	@step_defered_interest				money OUTPUT,
	@step_defered_overdue_interest		money = NULL OUTPUT,
	@op_details							xml OUTPUT
AS
  
SET NOCOUNT ON
SET @op_commit = 0

IF (@schedule_date = @date)
BEGIN
	IF ISNULL(@schedule_nu_interest, $0.00) + ISNULL(@schedule_interest, $0.00) > $0.00 OR
		ISNULL(@schedule_principal, $0.00) > $0.00
	BEGIN
		SET @op_commit = 1
		SET @step_overdue_percent = ISNULL(@schedule_nu_interest, $0.00) + ISNULL(@schedule_interest, $0.00) 
		SET @step_defered_interest = ISNULL(@schedule_defered_interest, $0.00)
		SET @step_defered_overdue_interest = ISNULL(@schedule_defered_overdue_interest, $0.00)
		SET @overdue_percent = @overdue_percent + @step_overdue_percent + @step_defered_interest + @step_defered_overdue_interest
		SET @step_overdue_principal = ISNULL(@schedule_principal, $0.00)
		SET @overdue_principal = @overdue_principal + @step_overdue_principal

		INSERT INTO #tbl_overdue(LOAN_ID, OVERDUE_DATE, OVERDUE_OP_ID, OVERDUE_PRINCIPAL, OVERDUE_PERCENT)
		VALUES(@loan_id, @date, -1, @step_overdue_principal, @step_overdue_percent + @step_defered_interest) 

		SET @nu_interest = $0.00
		SET @interest = $0.00
		SET @principal = @principal - @schedule_principal
		SET @deferable_interest = @deferable_interest - @step_defered_interest
		SET @deferable_overdue_interest = @deferable_overdue_interest - @step_defered_overdue_interest
		SET @schedule_nu_interest = $0.00
		SET @schedule_interest = $0.00
		SET @schedule_principal = $0.00
	END

	SET @step_overdue_insurance = $0.00
	SET @step_overdue_service_fee = $0.00
	IF ISNULL(@schedule_insurance, $0.00) > $0.00 OR ISNULL(@schedule_service_fee, $0.00) > $0.00
	BEGIN
		SET @step_overdue_insurance = ISNULL(@schedule_insurance, $0.00)
		SET @overdue_insurance = ISNULL(@overdue_insurance, $0.00) + @step_overdue_insurance

		SET @step_overdue_service_fee = ISNULL(@schedule_service_fee, $0.00)
		SET @overdue_service_fee = @overdue_service_fee + @step_overdue_service_fee
	END
END

RETURN(0)
GO