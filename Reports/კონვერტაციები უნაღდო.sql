DECLARE
	@start_date smalldatetime = '20170701',
	@end_date smalldatetime = '20171231';

SELECT
	d.REC_ID [საბუთის უნიკალური #],
	CAST(d.DOC_DATE AS date) [საბუთის თარიღი],
	d.DEBIT [დებეტი],
	dbo.clr_ansi_to_unicode(a1.DESCRIP) [დებიტის დასახელება],
	dbo.clr_ansi_to_unicode(ISNULL(c1.DESCRIP, '-')) [დებიტის მფლობელი კლიენტი],
	d.CREDIT [კრედიტი],
	dbo.clr_ansi_to_unicode(a2.DESCRIP) [კრედიტის დასახელება],
	dbo.clr_ansi_to_unicode(ISNULL(c2.DESCRIP, '-')) [კრედიტის მფლობელი კლიენტი],
	d.AMOUNT [თანხა A],
	d.ISO [ვალუტა A],
	d.AMOUNT1 [თანხა B],
	d.ISO1 [ვალუტა B],
	ISNULL(d.AMOUNT2, 0.0) [საკურსო სხვაობა],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება],
	d.RATE_AMOUNT [კურსი],
	(SELECT TOP (1) dc.TIME_OF_CHANGE FROM dbo.DOC_CHANGES dc WHERE dc.DOC_REC_ID = d.REC_ID ORDER BY dc.REC_ID ASC) [ოპერაციის შესრულების დრო]
FROM dbo.DOCS_CONV d
	INNER JOIN dbo.ACCOUNTS a1 ON a1.ACC_ID = d.DEBIT_ID
	LEFT JOIN dbo.CLIENTS c1 ON a1.CLIENT_NO = c1.CLIENT_NO
	INNER JOIN dbo.ACCOUNTS a2 ON a2.ACC_ID = d.CREDIT_ID
	LEFT JOIN dbo.CLIENTS c2 ON a2.CLIENT_NO = c2.CLIENT_NO
WHERE (d.DOC_DATE BETWEEN @start_date AND @end_date) 
	--AND (d.AMOUNT > 1000.0 OR d.AMOUNT1 > 1000.0)
UNION ALL
SELECT
	d.REC_ID [საბუთის უნიკალური #],
	CAST(d.DOC_DATE AS date) [საბუთის თარიღი],
	d.DEBIT [დებეტი],
	dbo.clr_ansi_to_unicode(a1.DESCRIP) [დებიტის დასახელება],
	dbo.clr_ansi_to_unicode(ISNULL(c1.DESCRIP, '')) [დებიტის მფლობელი კლიენტი],
	d.CREDIT [კრედიტი],
	dbo.clr_ansi_to_unicode(a2.DESCRIP) [კრედიტის დასახელება],
	dbo.clr_ansi_to_unicode(ISNULL(c2.DESCRIP, '-')) [კრედიტის მფლობელი კლიენტი],
	d.AMOUNT [თანხა A],
	d.ISO [ვალუტა A],
	d.AMOUNT1 [თანხა B],
	d.ISO1 [ვალუტა B],
	ISNULL(d.AMOUNT2, 0.0) [საკურსო სხვაობა],
	dbo.clr_ansi_to_unicode(d.DESCRIP) [დანიშნულება],
	d.RATE_AMOUNT [კურსი],
	(SELECT TOP (1) dc.TIME_OF_CHANGE FROM dbo.DOC_CHANGES_ARC dc WHERE dc.DOC_REC_ID = d.REC_ID ORDER BY dc.REC_ID ASC) [ოპერაციის შესრულების დრო]
FROM dbo.DOCS_ARC_CONV d
	INNER JOIN dbo.ACCOUNTS a1 ON a1.ACC_ID = d.DEBIT_ID
	LEFT JOIN dbo.CLIENTS c1 ON a1.CLIENT_NO = c1.CLIENT_NO
	INNER JOIN dbo.ACCOUNTS a2 ON a2.ACC_ID = d.CREDIT_ID
	LEFT JOIN dbo.CLIENTS c2 ON a2.CLIENT_NO = c2.CLIENT_NO
WHERE (d.DOC_DATE BETWEEN @start_date AND @end_date) 
	--AND (d.AMOUNT > 1000.0 OR d.AMOUNT1 > 1000.0)
ORDER BY d.REC_ID ASC