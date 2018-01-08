-- გატანები

DECLARE
	@start_date smalldatetime = '20170701',
	@end_date smalldatetime = '20171231';

DECLARE
	@bank_acc_list table (account TACCOUNT, iso char(3))

INSERT INTO @bank_acc_list ( account, iso )
	
VALUES 
	(1715001, 'GEL'), (1715001, 'USD'), (1715001, 'EUR'),
	(1704001, 'GEL'), (1714002, 'USD'), (1714002, 'EUR'), 
	(1702001, 'GEL'), (1712001, 'USD'), (1712001, 'EUR')

--  ჩარიცხვები. (დებეტი -ბანკის ანგ; კრედიტი- კლიენტის ანგ.)
SELECT
	CAST(d.DOC_DATE AS date) [საბუთის თაიღი],
	d.DEBIT,
	d.CREDIT,
	d.ISO [ვალუტა],
	d.AMOUNT [თანხა],
	d.AMOUNT_EQU [თანხა (ექვ)],
	CASE WHEN c.IS_RESIDENT = 0 THEN N'არარეზიდენტი' ELSE N'რეზიდენტი' END [რეზიდენტი/არარეზიდენტი],
	dbo.clr_ansi_to_unicode(c.DESCRIP) [კლიენტის დასახელება], 
	ISNULL(c.PERSONAL_ID, c.TAX_INSP_CODE) AS [პირადი ნომერი/საგადასახადო კოდი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება]
FROM dbo.DOCS_FULL_ALL d 
	INNER JOIN dbo.ACCOUNTS a_bank ON a_bank.ACC_ID = d.DEBIT_ID
	INNER JOIN @bank_acc_list al ON al.account = a_bank.ACCOUNT AND al.iso = a_bank.ISO
	INNER JOIN dbo.ACCOUNTS a_client ON a_client.ACC_ID = d.CREDIT_ID
		AND a_client.CLIENT_NO IS NOT NULL AND LEFT(CAST(a_client.BAL_ACC_ALT AS varchar(10)), 2) IN ('36', '45')
	
	INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = a_client.CLIENT_NO	
WHERE d.DOC_DATE BETWEEN @start_date AND @end_date
ORDER BY d.REC_ID

-- გადარიცხვები. (დებეტი-კლიენტის ანგ. ; კრედიტი-ბანკის ანგ.)
SELECT
	CAST(d.DOC_DATE AS date) [საბუთის თაიღი],
	d.DEBIT,
	d.CREDIT,
	d.ISO [ვალუტა],
	d.AMOUNT [თანხა],
	d.AMOUNT_EQU [თანხა (ექვ)],
	CASE WHEN c.IS_RESIDENT = 0 THEN N'არარეზიდენტი' ELSE N'რეზიდენტი' END [რეზიდენტი/არარეზიდენტი],
	--dbo.clr_ansi_to_unicode(c.DESCRIP) [კლიენტის დასახელება], 
	ISNULL(c.PERSONAL_ID, c.TAX_INSP_CODE) AS [პირადი ნომერი/საგადასახადო კოდი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება]
FROM dbo.DOCS_FULL_ALL d 
	INNER JOIN dbo.ACCOUNTS a_bank ON a_bank.ACC_ID = d.CREDIT_ID
	INNER JOIN @bank_acc_list al ON al.account = a_bank.ACCOUNT AND al.iso = a_bank.ISO
	INNER JOIN dbo.ACCOUNTS a_client ON a_client.ACC_ID = d.DEBIT_ID
		--AND a_client.CLIENT_NO IS NOT NULL AND LEFT(CAST(a_client.BAL_ACC_ALT AS varchar(10)), 2) IN ('36', '45')
	
	INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = a_client.CLIENT_NO	
WHERE d.DOC_DATE BETWEEN @start_date AND @end_date
ORDER BY d.REC_ID