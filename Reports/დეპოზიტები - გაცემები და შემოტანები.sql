﻿DECLARE
	@start_date smalldatetime = '20170701',
	@end_date smalldatetime = '20171231';

-- გატანები
SELECT
	CAST(d.DOC_DATE AS date) [საბუთის თაიღი],
	d.ISO [ვალუტა],
	d.AMOUNT [თანხა],
	d.AMOUNT_EQU [თანხა (ექვ)],
	CASE WHEN c.IS_RESIDENT = 0 THEN N'არარეზიდენტი' ELSE N'რეზიდენტი' END [რეზიდენტი/არარეზიდენტი],
	dbo.clr_ansi_to_unicode(ct.DESCRIP) AS [სამართლებრივი ფორმა],
	dbo.clr_ansi_to_unicode(c.DESCRIP) [კლიენტის დასახელება], 
	ISNULL(c.PERSONAL_ID, c.TAX_INSP_CODE) AS [პირადი ნომერი/საგადასახადო კოდი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება]
FROM dbo.DOCS_FULL_ALL d	
	INNER JOIN dbo.ACCOUNTS a2 ON d.DEBIT_ID = a2.ACC_ID
	INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = a2.CLIENT_NO
	INNER JOIN dbo.CLIENT_TYPES ct ON ct.CLIENT_TYPE = c.CLIENT_TYPE
WHERE d.DOC_DATE BETWEEN @start_date AND @end_date AND 
	d.DEBIT_ID IN (
		SELECT a.ACC_ID FROM dbo.ACCOUNTS a
		WHERE a.BAL_ACC_ALT IN (3609.00, 3619.00)
	)
	AND dbo.clr_ansi_to_unicode(d.DESCRIP) NOT LIKE N'%რეალიზაცია%'
ORDER BY d.REC_ID

-- შემოტანები
SELECT	
	CAST(d.DOC_DATE AS date) [საბუთის თაიღი],
	d.ISO [ვალუტა],
	d.AMOUNT [თანხა],
	d.AMOUNT_EQU [თანხა (ექვ)],
	CASE WHEN c.IS_RESIDENT = 0 THEN N'არარეზიდენტი' ELSE N'რეზიდენტი' END [რეზიდენტი/არარეზიდენტი],
	dbo.clr_ansi_to_unicode(ct.DESCRIP) AS [სამართლებრივი ფორმა],
	dbo.clr_ansi_to_unicode(c.DESCRIP) [კლიენტის დასახელება], 
	ISNULL(c.PERSONAL_ID, c.TAX_INSP_CODE) AS [პირადი ნომერი/საგადასახადო კოდი],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება]
FROM dbo.DOCS_FULL_ALL d	
	INNER JOIN dbo.ACCOUNTS a2 ON d.CREDIT_ID = a2.ACC_ID
	INNER JOIN dbo.CLIENTS c ON c.CLIENT_NO = a2.CLIENT_NO
	INNER JOIN dbo.CLIENT_TYPES ct ON ct.CLIENT_TYPE = c.CLIENT_TYPE
WHERE d.DOC_DATE BETWEEN @start_date AND @end_date AND 
	d.CREDIT_ID IN (
		SELECT a.ACC_ID FROM dbo.ACCOUNTS a
		WHERE a.BAL_ACC_ALT IN (3609.00, 3619.00)
	)
	AND dbo.clr_ansi_to_unicode(d.DESCRIP) NOT LIKE N'%რეალიზაცია%'
ORDER BY d.REC_ID
GO