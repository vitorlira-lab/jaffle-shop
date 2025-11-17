/*

with base_data as (
    -- Step 1: Union data from three source tables
    select ACCNT_CODE, TRANS_DATETIME, D_C, DESCRIPTN, ANAL_T0, ANAL_T1, ANAL_T2, ANAL_T3, ANAL_T4, ANAL_T5, ANAL_T6, ANAL_T7, ANAL_T8, ANAL_T9, AMOUNT, CONV_CODE, LAST_CHANGE_DATETIME, JRNAL_TYPE, JRNAL_SRCE, PERIOD 
    from prod_source.sun61data.gwl_a_salfldg
    union all
    select ACCNT_CODE, TRANS_DATETIME, D_C, DESCRIPTN, ANAL_T0, ANAL_T1, ANAL_T2, ANAL_T3, ANAL_T4, ANAL_T5, ANAL_T6, ANAL_T7, ANAL_T8, ANAL_T9, AMOUNT, CONV_CODE, LAST_CHANGE_DATETIME, JRNAL_TYPE, JRNAL_SRCE, PERIOD 
    from prod_source.sun61data.gwd_a_salfldg
    union all
    select ACCNT_CODE, TRANS_DATETIME, D_C, DESCRIPTN, ANAL_T0, ANAL_T1, ANAL_T2, ANAL_T3, ANAL_T4, ANAL_T5, ANAL_T6, ANAL_T7, ANAL_T8, ANAL_T9, AMOUNT, CONV_CODE, LAST_CHANGE_DATETIME, JRNAL_TYPE, JRNAL_SRCE, PERIOD 
    from prod_source.sun61data.gwr_a_salfldg
),

period_mapping as (
    -- Step 2: Bring in period metadata
    select 
        period,
        month_name,
        month_year,
        month_num,
        year_num
    from prod_source.analytics.sun_financial_period_mapping
),

joined_data as (
    -- Step 3: Join SUN data with period mapping
    select
        s.accnt_code,
        s.trans_datetime,
        s.d_c,
        s.descriptn,
        s.anal_t0,
        s.anal_t1,
        s.anal_t2,
        s.anal_t3,
        s.anal_t4,
        s.anal_t5,
        s.anal_t6,
        s.anal_t7,
        s.anal_t8,
        s.anal_t9,
        s.amount,
        s.conv_code,
        s.last_change_datetime,
        s.jrnal_type,
        s.jrnal_srce,
        s.period as sun_period,
        p.period as per_period,
        p.month_name,
        p.month_year,
        p.month_num,
        p.year_num
    from base_data s
    left join period_mapping p 
        on s.period = p.period
),

date_adjustments as (
    -- Step 4: Calculate period start/end and adjust the business date
    select
        accnt_code,
        trans_datetime,
        d_c,
        descriptn,
        anal_t0,
        anal_t1,
        anal_t2,
        anal_t3,
        anal_t4,
        anal_t5,
        anal_t6,
        anal_t7,
        anal_t8,
        anal_t9,
        amount,
        conv_code,
        last_change_datetime,
        jrnal_type,
        jrnal_srce,
        sun_period,
        per_period,
        month_name,
        month_year,
        month_num,
        year_num,
        cast(concat(month_num, '/01/', year_num) as datetime) as per_start,
        cast(last_day(cast(concat(month_num, '/01/', year_num) as datetime)) as datetime) as per_end,
        iff(trans_datetime < per_start or trans_datetime > per_end, per_start, trans_datetime) as new_date,
        case 
            when anal_t1 = '4200' and accnt_code = '602715' then 'WP1000'
            else anal_t2
        end as adjusted_anal_t2
    from joined_data
),

final_aggregated as (
    -- Step 5: Map field names for reporting
    select
        accnt_code as account_code,
        new_date as business_date,
        anal_t0 as company,
        anal_t1 as department,
        adjusted_anal_t2 as segment_code,
        anal_t3 as payroll_code,
        anal_t4 as fin_group5,
        anal_t5 as fin_group6,
        anal_t6 as fin_group7,
        anal_t7 as fin_group8,
        anal_t8 as fin_group9,
        anal_t9 as fin_group10,
        amount,
        conv_code as currency,
        trans_datetime,
        sun_period
    from date_adjustments
)

-- Step 6: Final aggregation
select
    business_date,
    currency,
    company,
    department,
    account_code,
    segment_code,
    payroll_code,
    fin_group5,
    fin_group6,
    fin_group7,
    fin_group8,
    fin_group9,
    fin_group10,
    sum(amount) as amount
from final_aggregated
group by all;

*/