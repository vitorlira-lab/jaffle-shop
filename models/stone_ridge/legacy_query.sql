WITH
    -- AUM joined with fund master data, with a rank based on default_fee_earning_aum_sort_order
    ORDERED_NAVS AS (
        SELECT
            N.NAV_ENTITY_ID,
            N.NAV_ENTITY_NAME,
            N.NAV_ENTITY_KIND,
            N.DATE,
            N.NAV                                                                                                                       AS AUM,
            N.NAV_KIND,
            N.NAV_SOURCE,
            N.SHARES_OUTSTANDING,
            N.ROUNDED_NAV_PER_SHARE                                                                                                     AS NAV_PER_SHARE,
            F.FUND_NAME,
            F.FUND_STRATEGY,
            F.IS_PRIVATE,
            F.INCEPTION_DATE,
            F.CLOSE_DATE,
            F.IS_ACTIVE,
            F.CUSIP,

            --For Energy, we receive the month start date from Box / INTERNAL_NAV_SERVICE.NAV, but it actually represents the month-end AUM.
            --So we convert source_as_of_date to the appropriate month-end date.
            CASE
                WHEN F.FUND_STRATEGY = 'Energy' THEN (DATE_TRUNC('month', N.SOURCE_AS_OF_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date
                ELSE N.SOURCE_AS_OF_DATE
                END                                                                                                                     AS SOURCE_AS_OF_DATE,
            N.BUSINESS_DATE,
            N.TIMESTAMP                                                                                                                 AS KNOWLEDGE_DATE,
            F.IS_SUBFUND,
            F.IS_INTERVAL_FUND,
            F.LIFEX_GENDER,
            F.LIFEX_OLDEST_BIRTH_DATE,
            F.LIFEX_BIRTH_YEAR,
            F.LIFEX_END_YEAR,
            F.LIFEX_STRATEGY,
            ROW_NUMBER() OVER (PARTITION BY N.DATE, N.NAV_ENTITY_NAME, N.NAV_ENTITY_KIND ORDER BY N.DEFAULT_FEE_EARNING_AUM_SORT_ORDER) AS RANK
        FROM
            RESEARCH.NAV N
                LEFT JOIN REFERENCE_DATA.FUND_MASTER F
                          ON N.NAV_ENTITY_ID = F.NAV_ENTITY_ID)

SELECT -- Select everything with rank 1
       N.DATE,
       N.NAV_ENTITY_ID,
       N.NAV_ENTITY_NAME,
       N.NAV_ENTITY_KIND,
       N.NAV_KIND,
       N.NAV_SOURCE,
       N.AUM,
       N.SHARES_OUTSTANDING,
       N.NAV_PER_SHARE,
       N.FUND_NAME,
       N.FUND_STRATEGY,
       N.IS_PRIVATE,
       N.INCEPTION_DATE,
       N.CLOSE_DATE,
       N.IS_ACTIVE,
       N.CUSIP,
       N.SOURCE_AS_OF_DATE,
       N.KNOWLEDGE_DATE,
       S.IS_BUSINESS_DAY,
       S.IS_MONTH_END_DATE,
       S.IS_QUARTER_END_DATE,
       S.IS_YEAR_END_DATE,
       N.IS_SUBFUND,
       N.IS_INTERVAL_FUND,
       N.LIFEX_GENDER,
       N.LIFEX_OLDEST_BIRTH_DATE,
       N.LIFEX_BIRTH_YEAR,
       N.LIFEX_END_YEAR,
       N.LIFEX_STRATEGY
FROM
    ORDERED_NAVS N
        --RESEARCH.NAV can have nav for in the future. Keep to current or prior business days only.
        JOIN ${ENV}_SHARED_DB.CALENDARS.SR_CALENDAR S
             ON N.DATE = S.AS_OF_DATE
            AND S.AS_OF_DATE <= CURRENT_DATE
WHERE
      RANK = 1
  AND N.NAV_SOURCE != 'US_BANK_PREPUBLISHED'
  AND N.DATE >= N.INCEPTION_DATE
  AND N.DATE <= COALESCE(N.CLOSE_DATE, '9999-12-31')                         --Only include AUM between inception and close dates.
  AND N.FUND_NAME NOT IN ('Longtail Holding Company', 'Collectibles', 'TRF') --We don't charge fees on these funds
ORDER BY
    DATE DESC,
    NAV_ENTITY_NAME,
    NAV_ENTITY_KIND;