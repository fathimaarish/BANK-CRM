create database fabankcrm;
use fabankcrm;



--------------------------------------- Data Preparation -------------------------------------------------------

select 
count(case when ci.CustomerID is null then 1 end) as CustomerId_null_count,
count(case when ci.Surname is null then 1 end) as Surname_null_count,
count(case when ci.Age is null then 1 end) as Age_null_count,
count(case when ci.GenderID is null then 1 end) as GenderID_null_count,
count(case when ci.EstimatedSalary is null then 1 end) as EstimatedSalary_null_count,
count(case when ci.GeographyID is null then 1 end) as GeographyID_null_count,
count(case when ci.Bank_doj is null then 1 end) as Bank_doj_null_count,
count(case when bc.CustomerID is null then 1 end) as Bank_CustomerId_null_count,
count(case when bc.CreditScore is null then 1 end) as Bank_CreditScore_null_count,
count(case when bc.Tenure is null then 1 end) as Bank_Tenure_null_count,
count(case when bc.Balance is null then 1 end) as Bank_Balance_null_count,
count(case when bc.NumOfProducts is null then 1 end) as Bank_NumOfProducts_null_count,
count(case when bc.HasCrCard is null then 1 end) as Bank_HasCrCredit_null_count,
count(case when bc.IsActiveMember is null then 1 end) as Bank_IsActiveMember_null_count,
count(case when bc.Exited is null then 1 end) as Bank_Exited_null_count
from customerinfo ci join bank_churn bc ON ci.CustomerId = bc.CustomerId;


-- changed the data type of Bank date of joining column to DATE 

update fabankcrm.customerinfo
set Bank_doj = date_format(str_to_date(Bank_Doj, '%d/%m/%Y'), '%m/%d/%Y');


---------------------------- Querying and finding insights ------------------------------

-- Identify the top 5 customers with the highest Estimated Salary in the last quarter of the year.

with bank_data as (
SELECT CustomerID, EstimatedSalary,(str_to_date(Bank_doj, "%m/%d/%Y")) as  DoJ_date
FROM fabankcrm.customerinfo)
select * , year(DoJ_date), quarter(DoJ_date) from bank_data
where quarter(DoJ_date)= 4 
order by EstimatedSalary desc
limit 5;

-- Calculate the average number of products used by customers who have a credit card.


select round(avg(NumOfProducts),2) as Average_number_of_products from bank_churn
where HasCrCard = 1;

-- Compare the average credit score of customers who have exited and those who remain.

select e.ExitCategory, round(avg(bc.CreditScore),2) as Average_credit_score from bank_churn bc
join exitcustomer e ON bc.Exited = e.ExitID
group by e.ExitCategory;

-- Which gender has a higher average estimated salary, and how does it relate to the number of active accounts? 

select g.GenderCategory, a.ActiveCategory, round(avg(ci.EstimatedSalary),2) as Average_estimated_salary 
from customerinfo ci 
join bank_churn bc ON ci.CustomerID = bc.CustomerID
Join activecustomer a ON bc.IsActiveMember = a.ActiveID
Join gender g ON ci.GenderID = g.GenderID
group by a.ActiveCategory, g.GenderCategory
order by Average_estimated_salary desc; 


-- Segment the customers based on their credit score and identify the segment with the highest exit rate. 

With count_of_churned as
(select count(*) as churned_customers from bank_churn
where Exited = 1)
Select case
	when CreditScore >=300 and CreditScore<580 then "Poor Credit score"
	when CreditScore >=580 and CreditScore<670 then "Fair Credit score"
	when CreditScore >=670 and CreditScore<740 then "Good Credit score"
	when CreditScore >=740 and CreditScore<800 then "Very Good Credit score"
else "Excellent Credit score"
end as CreditScore_segment, count(*) as Total_customers,
ROUND((SELECT churned_customers FROM count_of_churned)/count(*),2) as Exit_rate
from bank_churn
group by CreditScore_segment
order by Exit_rate;

-- Find out which geographic region has the highest number of active customers with a tenure greater than 5 years.

select g.GeographyLocation, count(*) As Highest_Active_customers from customerinfo ci
Join Bank_churn bc ON ci.CustomerID = bc.CustomerID
join geography g on ci.GeographyID = g.GeographyID
where bc.IsActiveMember = 1 and bc.Tenure>5
group by g.GeographyLocation
order by Highest_Active_customers desc
limit 3;


-- Examine the trend of customer joining over time and identify any seasonal patterns (yearly or monthly). Prepare the data through SQL and then visualize it.
-- first we will extract the relevant data to observe any particular trends in customer joining the bank
-- we can see from the below result, that in year 2019 

select year(Bank_doj) as joining_year, month(Bank_doj) as joining_month, count(*) as Total_customers,
g.GeographyLocation, Age from customerinfo ci
join geography g on ci.GeographyID = g.GeographyID
group by joining_year, joining_month, g.GeographyLocation, Age
order by Total_customers desc, joining_year desc;

-- Using SQL, write a query to find out the average tenure of the people who have exited in each 
-- age bracket (18-30, 30-50, 50+).

select 
case
	when ci.Age>17 and ci.Age<=30 then '18-30'
	when ci.Age>29 and ci.Age<=50 then '30-50'
    else '50+'
end as Age_group,
round(avg(bc.Tenure),2) as Average_Tenure from bank_churn bc
join customerinfo ci ON bc.CustomerId = ci.CustomerId
where bc.Exited = 1    -- exited=1 defines the customers who are churned. 
group by Age_group;

-- Rank each bucket of credit score as per the number of customers who have churned the bank.

with cte_credit_score_buckets as (
 select bc.CustomerId, 
 CASE
	when bc.CreditScore between 800 and 850 then 'Excellent'
    when bc.CreditScore between 740 and 799 then 'Very Good'
    when bc.CreditScore between 670 and 739 then 'Good'
    when bc.CreditScore between 580 and 669 then 'Fair'
    when bc.CreditScore between 300 and 579 then 'Poor'
    else 'Unknown'
 END as credit_score_bucket, bc.Exited
 from bank_churn bc)
 
 select credit_score_bucket, count(*) as num_churned_customers,
 rank() over(order by count(*) desc) as rank_by_churned
 from cte_credit_score_buckets
 where Exited = 1
 group by credit_score_bucket
 order by rank_by_churned;
 
-- According to the age buckets find the number of customers who have a credit card. Also retrieve those 
-- buckets who have lesser than average number of credit cards per bucket.

with cte_age_buckets as (
select ci.CustomerId,
case
	when ci.Age between 18 and 30 then '18-30'
	when ci.Age between 31 and 50 then '31-43'
    when ci.Age between 44 and 56 then '44-56'
    when ci.Age between 57 and 66 then '57-66'
    else '66+'
end as Age_group, bc.HasCrCard from customerinfo ci inner join bank_churn bc ON ci.CustomerId = bc.CustomerId),
cte_having_credit_card as (
	select Age_group, count(case when HasCrCard =1 then 1 end) as num_credit_card_holders
	from cte_age_buckets group by Age_group)
    
select Age_group, num_credit_card_holders from cte_having_credit_card
where num_credit_card_holders < (select avg(num_credit_card_holders) from cte_having_credit_card)
order by num_credit_card_holders;
 
 -- Write the query to get the customer ids, their last name and whether they are active or not for the 
-- customers whose surname  ends with “on”. 

 select ci.CustomerId, ci.Surname,
 CASE when bc.IsActiveMember = 1 then 'Active' else 'Inactive' END as Activity_status
 from customerinfo ci
 join bank_churn bc on ci.CustomerId = bc.CustomerId
 where ci.Surname like '%on';
 
 -- Using SQL, write a query to find out the gender wise average income of male and female in each geography id.
-- Also rank the gender according to the average value. (SQL)

with ranked_salaries as (
	select g.GenderID, geo.GeographyID, g.GenderCategory, geo.GeographyLocation, avg(ci.EstimatedSalary) as Average_Salary,
	dense_rank() over(partition by g.GenderID order by avg(ci.EstimatedSalary) DESC) As ranked_salary
	from customerinfo ci join gender g ON ci.GenderID = g.GenderID
	Join geography geo ON ci.GeographyID = geo.GeographyID
	group by g.GenderID, geo.GeographyID, g.GenderCategory, geo.GeographyLocation)

select rs.GenderCategory as Gender, rs.GeographyLocation as Country, round(rs.Average_salary,2) as
Average_Salary, rs.ranked_salary from ranked_salaries rs;
 
 -- Rank the Locations as per the number of people who have churned the bank and average balance of the learners.
 
with cte_churn_info as (
select ci.GeographyID, bc.Exited, bc.Balance from customerinfo ci 
INNER join bank_churn bc on ci.CustomerId = bc.CustomerId),

cte_churn_count as (
select GeographyID, COUNT(CASE WHEN Exited = 1 THEN 1 END) as churn_count from cte_churn_info
GROUP by GeographyID),

cte_avg_balance as (
select GeographyID, AVG(Balance) as avg_balance from cte_churn_info
GROUP BY GeographyID)

select g.GeographyLocation,
    cc.churn_count,
    round(ab.avg_balance,2) as Average_balance,
    RANK() OVER (ORDER BY cc.churn_count DESC, ab.avg_balance DESC) as location_rank
from geography g
LEFT join cte_churn_count cc on g.GeographyID = cc.GeographyID
LEFT join cte_avg_balance ab on g.GeographyID = ab.GeographyID
order by location_rank;


-- As we can see that the “CustomerInfo” table has the CustomerID and Surname, now if we have to join it
-- with a table where the primary key is also a combination of CustomerID and Surname, come up with a column 
-- where the format is “CustomerID_Surname”.

select concat(CAST(CustomerId as CHAR), '_', Surname) as CustomerID_Surname
from customerinfo;

-- Without using “Join”, can we get the “ExitCategory” from ExitCustomers table to Bank_Churn table? If yes, do this using SQL.

SELECT CustomerId,Exited
FROM bank_churn,exitcustomer
WHERE Exited=Exited;

-- Utilize SQL queries to segment customers based on demographics and account details.

-- Segmentation by Gender:

SELECT ci.GenderID, COUNT(*) AS TotalCustomers, round(AVG(ci.Age)) AS AvgAge, round(AVG(bc.Balance),2) AS AvgBalance, 
round(AVG(bc.NumOfProducts),2) AS AvgNumOfProducts, round(AVG(ci.EstimatedSalary),2) AS AvgSalary
FROM customerInfo ci join bank_churn bc ON ci.CustomerId = bc.CustomerId
GROUP BY GenderID;

-- Segmentation by Country:

SELECT g.GeographyLocation, COUNT(*) AS TotalCustomers, round(AVG(ci.Age)) AS AvgAge, round(AVG(bc.Balance),2) AS AvgBalance, 
round(AVG(bc.NumOfProducts),2) AS AvgNumOfProducts, round(AVG(ci.EstimatedSalary),2) AS AvgSalary
FROM customerInfo ci join bank_churn bc ON ci.CustomerId = bc.CustomerId
join geography g ON ci.GeographyID = g.GeographyID
GROUP BY g.GeographyLocation;

-- Segmentation by Credit Card Status:

SELECT cc.category, COUNT(*) AS TotalCustomers, round(AVG(ci.Age)) AS AvgAge, round(AVG(bc.Balance),2) AS AvgBalance, 
round(AVG(bc.NumOfProducts),2) AS AvgNumOfProducts, round(AVG(ci.EstimatedSalary),2) AS AvgSalary
FROM customerInfo ci join bank_churn bc ON ci.CustomerId = bc.CustomerId
join creditcard cc ON bc.HasCrCard = cc.CreditID
GROUP BY cc.category;