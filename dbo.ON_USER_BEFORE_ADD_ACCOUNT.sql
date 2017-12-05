ALTER PROCEDURE dbo.ON_USER_BEFORE_ADD_ACCOUNT (
	@user_id int OUTPUT,		-- еим юлютдас юмбюришс
	@dept_no int OUTPUT,		-- викиюки
	@account TACCOUNT OUTPUT,
	@iso TISO OUTPUT,
	@bal_acc_alt TBAL_ACC OUTPUT,
	@act_pas tinyint OUTPUT,
	@rec_state tinyint OUTPUT,
	@descrip varchar(100) OUTPUT,
	@descrip_lat varchar(100) OUTPUT,
	@acc_type tinyint OUTPUT, 
	@acc_subtype int OUTPUT, 
	@client_no int OUTPUT,
	@date_open smalldatetime OUTPUT,
	@period smalldatetime OUTPUT,
	@tariff smallint OUTPUT,
	@product_no int OUTPUT,
	@min_amount money OUTPUT,
	@min_amount_new money OUTPUT,
	@min_amount_check_date smalldatetime OUTPUT,
	@blocked_amount money OUTPUT,
	@block_check_date smalldatetime OUTPUT,
	@prof_loss_acc TACCOUNT OUTPUT,
	@flags int OUTPUT,
	@remark varchar(100) OUTPUT,
	@code_phrase varchar(20) OUTPUT,
	@bal_acc_old decimal(10,4) OUTPUT,
	@bal_acc2 decimal(10,4) OUTPUT,
	@bal_acc3 decimal(10,4) OUTPUT,
@responsible_user_id int OUTPUT,
	@is_control bit OUTPUT,
	@is_incasso bit OUTPUT,

	@iban_usage_type tinyint OUTPUT,
@auto_acc_num_template varchar(100) OUTPUT,
	@auto_acc_num_min_value TACCOUNT OUTPUT
) 
AS

SET NOCOUNT ON;

RETURN 0
GO
