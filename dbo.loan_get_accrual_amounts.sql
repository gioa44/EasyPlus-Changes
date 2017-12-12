ALTER PROCEDURE dbo.loan_get_accrual_amounts
	@loan_id									int,
	@guarantee									bit,
	@disburse_type								int,
    @date										smalldatetime,
	@schedule_control							bit = 1, -- ÃÀÒÉÝáÖËÉ ÐÒÏÝÄÍÔÉ ÃÀÀÍÂÀÒÉÛÃÄÓ ÂÒÀ×ÉÊÉÓ ÐÒÏÝÄÍÔÉÃÀÍ  1, ÈÖ ÃÀÒÜÄÍÉËÉ ÞÉÒÉÃÀÍ 0
	@schedule_date								smalldatetime,
	@end_date									smalldatetime, 
	@schedule_interest							money,
	@schedule_nu_interest						money,
	@schedule_balance							money,
	@schedule_pay_interest						bit,
	@schedule_nu_interest_correction			money,
	@schedule_interest_correction				money,	


	@calc_date									smalldatetime,
	@prev_step									smalldatetime,
	@interest_flags								int,
	@penalty_flags								int,
	@nu_intrate									money, -- ÂÀÌÏÖÚÄÍÄÁÄË ÈÀÍáÀÆÄ ÃÀÒÉÝáÖËÉ ÐÒÏÝÄÍÔÉ
	@intrate									money, -- ÓÀÐÒÏÝÄÍÔÏ ÂÀÍÀÊÅÄÈÉ
	@basis										int,
	@penalty_intrate							money, -- ÓÀãÀÒÉÌÏ ÐÒÏÝÄÍÔÉ
	@penalty_delta								bit = 0,


	/*ძირითადი თანხები */
	@nu_principal								money,
	@principal									money,
	@overdue_principal							money,
	@calloff_principal							money,
	@writeoff_principal							money,
	/*End ძირითადი თანხები */

	/*პროცენტები*/
	@overdue_percent							money,
	@calloff_percent							money,
	@writeoff_percent							money,
	/*End პროცენტები*/

	@nu_interest								money OUTPUT, 
	@nu_interest_daily							money OUTPUT,
	@nu_interest_fraction						TFRACTION OUTPUT,

	@interest									money OUTPUT,
	@interest_daily								money OUTPUT,
	@interest_fraction							TFRACTION OUTPUT, 
	
	@overdue_principal_interest					money OUTPUT,
	@overdue_principal_interest_daily			money OUTPUT,
	@overdue_principal_interest_fraction		TFRACTION OUTPUT,
	@overdue_principal_penalty					money OUTPUT,
	@overdue_principal_penalty_daily			money OUTPUT,
	@overdue_principal_penalty_fraction			TFRACTION OUTPUT,
	@overdue_percent_penalty					money OUTPUT,
	@overdue_percent_penalty_daily				money OUTPUT,
	@overdue_percent_penalty_fraction			TFRACTION OUTPUT,

	@calloff_principal_interest					money OUTPUT,
	@calloff_principal_interest_daily			money OUTPUT,
	@calloff_principal_interest_fraction		TFRACTION OUTPUT,
	@calloff_principal_penalty					money OUTPUT,
	@calloff_principal_penalty_daily			money OUTPUT,
	@calloff_principal_penalty_fraction			TFRACTION OUTPUT,
	@calloff_percent_penalty					money OUTPUT,
	@calloff_percent_penalty_daily				money OUTPUT,
	@calloff_percent_penalty_fraction			TFRACTION OUTPUT,

	@writeoff_principal_penalty					money OUTPUT,
	@writeoff_principal_penalty_daily			money OUTPUT,
	@writeoff_principal_penalty_fraction		TFRACTION OUTPUT,
	@writeoff_percent_penalty					money OUTPUT,
	@writeoff_percent_penalty_daily				money OUTPUT,	
	@writeoff_percent_penalty_fraction			TFRACTION OUTPUT
AS
SET NOCOUNT ON;

DECLARE
	@is_nbg bit

SET @is_nbg = 0;
IF EXISTS (SELECT * FROM dbo.DEPTS D WHERE D.CODE9 = 220101107) -- NBG
	SET @is_nbg = 1;

IF @is_nbg = 1
BEGIN
	EXEC dbo.loan_get_accrual_amounts_nbg
		@loan_id = @loan_id,
		@guarantee = @guarantee,
		@disburse_type = @disburse_type,
		@date = @date,
		@schedule_control = @schedule_control,
		@schedule_date = @schedule_date,
		@end_date = @end_date, 
		@schedule_interest = @schedule_interest,
		@schedule_nu_interest = @schedule_nu_interest,
		@schedule_balance = @schedule_balance,
		@schedule_pay_interest = @schedule_pay_interest,
		@schedule_nu_interest_correction = @schedule_nu_interest_correction,
		@schedule_interest_correction = @schedule_interest_correction,	


		@calc_date = @calc_date,
		@prev_step = @prev_step,
		@interest_flags = @interest_flags,
		@penalty_flags = @penalty_flags,
		@nu_intrate = @nu_intrate,
		@intrate = @intrate,
		@basis = @basis,
		@penalty_intrate = @penalty_intrate,
		@penalty_delta = @penalty_delta,


		/*ძირითადი თანხები */
		@nu_principal = @nu_principal,
		@principal = @principal,
		@overdue_principal = @overdue_principal,
		@calloff_principal = @calloff_principal,
		@writeoff_principal = @writeoff_principal,
		/*End ძირითადი თანხები */

		/*პროცენტები*/
		@overdue_percent = @overdue_percent,
		@calloff_percent = @calloff_percent,
		@writeoff_percent = @writeoff_percent,
		/*End პროცენტები*/

		@nu_interest = @nu_interest OUTPUT, 
		@nu_interest_daily = @nu_interest_daily OUTPUT,
		@nu_interest_fraction = @nu_interest_fraction OUTPUT,

		@interest = @interest OUTPUT,
		@interest_daily = @interest_daily OUTPUT,
		@interest_fraction = @interest_fraction OUTPUT, 
		
		@overdue_principal_interest = @overdue_principal_interest OUTPUT,
		@overdue_principal_interest_daily = @overdue_principal_interest_daily OUTPUT,
		@overdue_principal_interest_fraction = @overdue_principal_interest_fraction OUTPUT,
		@overdue_principal_penalty = @overdue_principal_penalty OUTPUT,
		@overdue_principal_penalty_daily = @overdue_principal_penalty_daily OUTPUT,
		@overdue_principal_penalty_fraction = @overdue_principal_penalty_fraction OUTPUT,
		@overdue_percent_penalty = @overdue_percent_penalty OUTPUT,
		@overdue_percent_penalty_daily = @overdue_percent_penalty_daily OUTPUT,
		@overdue_percent_penalty_fraction = @overdue_percent_penalty_fraction OUTPUT,

		@calloff_principal_interest = @calloff_principal_interest OUTPUT,
		@calloff_principal_interest_daily = @calloff_principal_interest_daily OUTPUT,
		@calloff_principal_interest_fraction = @calloff_principal_interest_fraction OUTPUT,
		@calloff_principal_penalty = @calloff_principal_penalty OUTPUT,
		@calloff_principal_penalty_daily = @calloff_principal_penalty_daily OUTPUT,
		@calloff_principal_penalty_fraction = @calloff_principal_penalty_fraction OUTPUT,
		@calloff_percent_penalty = @calloff_percent_penalty OUTPUT,
		@calloff_percent_penalty_daily = @calloff_percent_penalty_daily OUTPUT,
		@calloff_percent_penalty_fraction = @calloff_percent_penalty_fraction OUTPUT,

		@writeoff_principal_penalty = @writeoff_principal_penalty OUTPUT,
		@writeoff_principal_penalty_daily = @writeoff_principal_penalty_daily OUTPUT,
		@writeoff_principal_penalty_fraction = @writeoff_principal_penalty_fraction OUTPUT,
		@writeoff_percent_penalty = @writeoff_percent_penalty OUTPUT,
		@writeoff_percent_penalty_daily = @writeoff_percent_penalty_daily OUTPUT,	
		@writeoff_percent_penalty_fraction = @writeoff_percent_penalty_fraction OUTPUT	
	RETURN 0;
END

DECLARE
	@tmp_money money,
	@fraction decimal(28, 15)

IF (@calc_date > @date) OR (@prev_step > @date)
	RETURN 0

IF @interest_flags & 0x0001 <> 0  -- ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ ÐÒÏÝÄÍÔÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	IF @schedule_control = 1 AND @disburse_type <> 4 AND @schedule_date IS NOT NULL
	BEGIN
		IF (@schedule_date > @date)
		BEGIN
			SET @nu_interest = ISNULL(@nu_interest, $0.00)
			SET @interest = ISNULL(@interest, $0.00)
			SET	@schedule_nu_interest_correction = ISNULL(@schedule_nu_interest_correction, $0.00)

			SET @fraction = convert(decimal(28, 15), (@schedule_nu_interest - @schedule_nu_interest_correction)) * DATEDIFF(dd, @prev_step, @date) / DATEDIFF(dd, @prev_step, @schedule_date) + @schedule_nu_interest_correction + @nu_interest_fraction
			SET @tmp_money = @nu_interest
			SET @nu_interest = ROUND(@fraction, 2, 1)
			SET @nu_interest_daily = @nu_interest - @tmp_money
			SET @nu_interest_fraction = @fraction - ROUND(@fraction, 2, 1)

			SET	@schedule_interest_correction = ISNULL(@schedule_interest_correction, $0.00)
			
			SET @fraction = convert(decimal(28, 15), (@schedule_interest - @schedule_interest_correction)) * DATEDIFF(dd, @prev_step, @date) / DATEDIFF(dd, @prev_step, @schedule_date) + @schedule_interest_correction + @interest_fraction
			SET @tmp_money = @interest
			SET @interest = ROUND(@fraction, 2, 1)
			SET @interest_daily = @interest - @tmp_money
			SET @interest_fraction = @fraction - ROUND(@fraction, 2, 1)
		END
		ELSE
		BEGIN
			SET @tmp_money = @nu_interest
			SET @nu_interest = ISNULL(@schedule_nu_interest, $0.00)
			SET @nu_interest_daily = ISNULL(@schedule_nu_interest, $0.00) - @tmp_money
			SET @nu_interest_fraction = $0.00
			
			SET @tmp_money = @interest
			SET @interest = ISNULL(@schedule_interest, $0.00)
			SET @interest_daily = ISNULL(@schedule_interest, $0.00) - @tmp_money
			SET @interest_fraction = $0.00
		END
	END
	ELSE
	BEGIN -- დაერიცხოს დღეების მიხედვით
		IF @date < @end_date
		BEGIN
			SET @fraction = convert(decimal(28, 15), @nu_principal) * DATEDIFF(dd, @calc_date, @date) * @nu_intrate / @basis / 100 + @nu_interest_fraction
			SET @nu_interest_daily = ROUND(@fraction, 2, 1)
			SET @nu_interest = @nu_interest + @nu_interest_daily
			SET @nu_interest_fraction = @fraction - ROUND(@fraction, 2, 1)
		END

		SET @fraction = convert(decimal(28, 15), @principal) * DATEDIFF(dd, @calc_date, @date) * @intrate / @basis / 100 + @interest_fraction
		SET @interest_daily = ROUND(@fraction, 2, 1)
		SET @interest = @interest + @interest_daily
		SET @interest_fraction = @fraction - ROUND(@fraction, 2, 1)
	END
END

IF @interest_flags & 0x0002 <> 0 -- ÅÀÃÀÂÀÃÀÝËÄÁÖË ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ  ÐÒÏÝÄÍÔÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	SET @fraction = convert(decimal(28, 15), @overdue_principal) * DATEDIFF(dd, @calc_date, @date) * @intrate / @basis / 100 + @overdue_principal_interest_fraction
	SET @overdue_principal_interest_daily = ROUND(@fraction, 2, 1)
	SET @overdue_principal_interest = @overdue_principal_interest + @overdue_principal_interest_daily
	SET @overdue_principal_interest_fraction = @fraction - ROUND(@fraction, 2, 1)
END

IF @interest_flags & 0x0004 <> 0 -- ÂÀÌÏÈáÏÅÉË ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ  ÐÒÏÝÄÍÔÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	SET @fraction = @calloff_principal * DATEDIFF(dd, @calc_date, @date) * @intrate / @basis / 100 + @calloff_principal_interest_fraction
	SET @calloff_principal_interest_daily = ROUND(@fraction, 2, 1)
	SET @calloff_principal_interest = @calloff_principal_interest + @calloff_principal_interest_daily
	SET @calloff_principal_interest_fraction = @fraction - ROUND(@fraction, 2, 1)
END

IF @penalty_flags & 0x0001 <> 0 -- ÅÀÃÀÂÀÃÀÝËÄÁÖË ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	DECLARE
		@overdue_principal_19 money
		
	IF (@overdue_principal > $0.00) AND (EXISTS (SELECT CODE9 FROM dbo.DEPTS (NOLOCK) WHERE CODE9 IN ('220101710', '220101715'))) -- Invest
	BEGIN
		SELECT 
			TOP 1 @overdue_principal_19 = AMOUNT
		FROM dbo.LOAN_OPS (NOLOCK) 
		WHERE LOAN_ID = @loan_id AND OP_TYPE = 218
		ORDER BY OP_ID DESC
		
		IF @overdue_principal_19 IS NOT NULL
		BEGIN
			SET @fraction = convert(decimal(28, 15), @overdue_principal_19) * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @overdue_principal_penalty_fraction
			SET @overdue_principal_penalty_daily = ROUND(@fraction, 2, 1)
			SET @overdue_principal_penalty = @overdue_principal_penalty + @overdue_principal_penalty_daily
			SET @overdue_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
		END
	END
	ELSE
	BEGIN
		IF @penalty_delta = 1
		BEGIN
			SET @fraction = convert(decimal(28, 15), @overdue_principal) * DATEDIFF(dd, @calc_date, @date) * ABS(@penalty_intrate - (@intrate / @basis)) / 100 + @overdue_principal_penalty_fraction
			SET @overdue_principal_penalty_daily = ROUND(@fraction, 2, 1)
			SET @overdue_principal_penalty = @overdue_principal_penalty + @overdue_principal_penalty_daily
			SET @overdue_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
		END
		ELSE
		BEGIN
			SET @fraction = convert(decimal(28, 15), @overdue_principal) * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @overdue_principal_penalty_fraction
			SET @overdue_principal_penalty_daily = ROUND(@fraction, 2, 1)
			SET @overdue_principal_penalty = @overdue_principal_penalty + @overdue_principal_penalty_daily
			SET @overdue_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
		END
	END
END

IF @penalty_flags & 0x0002 <> 0 -- ÅÀÃÀÂÀÃÀÝÉËÄÁÖË ÐÒÏÝÄÍÔÆÄ ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	--IF (@guarantee = 0) OR (@date <= @end_date)  -- ÀÌÉÈ ÃÀÅÀÆÙÅÄÅÈ ÂÀÒÀÍÔÉÉÓ ÅÀÃÉÓ ÀÌÏßÖÒÅÉÓ ÃÒÏÓ ÀÒ ÃÀáÖÒÅÉÓ ÛÄÌÈáÅÄÅÀÓ 
	--BEGIN
		SET @fraction = convert(decimal(28, 15), @overdue_percent) * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @overdue_percent_penalty_fraction
		SET @overdue_percent_penalty_daily = ROUND(@fraction, 2, 1)
		SET @overdue_percent_penalty = @overdue_percent_penalty + @overdue_percent_penalty_daily
		SET @overdue_percent_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
	--END
END

IF @penalty_flags & 0x0004 <> 0 -- ÂÀÌÏÈáÏÅÉË ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ  ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	IF @penalty_delta = 1
	BEGIN
		SET @fraction = @calloff_principal * DATEDIFF(dd, @calc_date, @date) * ABS(@penalty_intrate - (@intrate / @basis)) / 100 + @calloff_principal_penalty_fraction
		SET @calloff_principal_penalty_daily = ROUND(@fraction, 2, 1)
		SET @calloff_principal_penalty = @calloff_principal_penalty + @calloff_principal_penalty_daily
		SET @calloff_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
	END
	ELSE
	BEGIN
		SET @fraction = @calloff_principal * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @calloff_principal_penalty_fraction
		SET @calloff_principal_penalty_daily = ROUND(@fraction, 2, 1)
		SET @calloff_principal_penalty = @calloff_principal_penalty + @calloff_principal_penalty_daily
		SET @calloff_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
	END
END

IF @penalty_flags & 0x0008 <> 0 -- ÂÀÌÏÈáÏÅÉË ÐÒÏÝÄÍÔÆÄ  ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	SET @fraction = @calloff_percent * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @calloff_percent_penalty_fraction
	SET @calloff_percent_penalty_daily = ROUND(@fraction, 2, 1)
	SET @calloff_percent_penalty = @calloff_percent_penalty + @calloff_percent_penalty_daily
	SET @calloff_percent_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
END

IF @penalty_flags & 0x0010 <> 0 -- ÜÀÌÏßÄÒÉË ÞÉÒÉÈÀÃ ÈÀÍáÀÆÄ  ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	SET @fraction = @writeoff_principal * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @writeoff_principal_penalty_fraction
	SET @writeoff_principal_penalty_daily = ROUND(@fraction, 2, 1)
	SET @writeoff_principal_penalty = @writeoff_principal_penalty + @writeoff_principal_penalty_daily
	SET @writeoff_principal_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
END

IF @penalty_flags & 0x0020 <> 0 -- ÜÀÌÏßÄÒÉË ÐÒÏÝÄÍÔÆÄ  ãÀÒÉÌÉÓ ÃÀÒÉÝáÅÀ
BEGIN
	SET @fraction = @writeoff_percent * DATEDIFF(dd, @calc_date, @date) * @penalty_intrate / 100 + @writeoff_percent_penalty_fraction
	SET @writeoff_percent_penalty_daily = ROUND(@fraction, 2, 1)
	SET @writeoff_percent_penalty = @writeoff_percent_penalty + @writeoff_percent_penalty_daily
	SET @writeoff_percent_penalty_fraction = @fraction - ROUND(@fraction, 2, 1)
END
