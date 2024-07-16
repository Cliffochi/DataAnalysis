-- previewing both tables that we are going to work with in this project

SELECT *
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 2,4

-- save this for later
SELECT *
FROM covid_data_project..CovidVaccinations
ORDER BY 3,4;

-- select the data that we are going to be using from the CovidDeaths table
SELECT Location, date, total_cases, new_cases, total_deaths, population
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL 
--AND total_cases IS NOT NULL AND total_deaths IS NOT NULL
ORDER BY 1,2;

-- let's look at the total cases of infections v total deaths per country
-- shows the probability of dying from covid in a given country if you were infected
SELECT Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS death_percentage
FROM covid_data_project..CovidDeaths
ORDER BY 1,2;

-- this query did not run because of 'Operand data type nvarchar is invalid for divide operator' error. we have to convert the columns to either float or int to run the operation
-- converting the two columns to float and repeating the previous operation
SELECT Location, date, 
       CAST(total_cases AS FLOAT) AS total_cases_numeric, 
       CAST(total_deaths AS FLOAT) AS total_deaths_numeric, 
       (CAST(total_deaths AS FLOAT) / CAST(total_cases AS FLOAT)) * 100 AS death_percentage
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2;

-- the operations run well while retaining the null values
-- we can narrow down to specific countries and see how the covid pandemic affected them
-- we will take Kenya as an example in this case
-- the significance of this percentage death is that it shows the chances of one dying of covid if they got infected at a given period in time
-- in Kenya the likelihood of dying from covid at the beginning of 2020 was about 10% then it dropped quite fast over the year (2020) to 1.7% at the end of the year
-- the chances of dying from covid remained at 1.7% till 2021 Q4 when the percentage spiked to 2%: this can be attributed to newer strains of the virus
-- the deaths dropped to 1.7 again in Q1 of 2022 then further declined to 1.6 later in the year and has since maintained that percentage (as of Q2 2024)
SELECT Location, date, 
       CAST(total_cases AS FLOAT) AS total_cases_numeric, 
       CAST(total_deaths AS FLOAT) AS total_deaths_numeric, 
       (CAST(total_deaths AS FLOAT) / CAST(total_cases AS FLOAT)) * 100 AS death_percentage
FROM covid_data_project..CovidDeaths
WHERE Location like '%Kenya%'
ORDER BY 1,2;

-- total cases vs the population (Kenya)
SELECT Location, date, population,
       CAST(total_cases AS FLOAT) AS total_cases_numeric,
       (CAST(total_cases AS FLOAT)/(population)) * 100 AS PercentagePopulationInfected
FROM covid_data_project..CovidDeaths
WHERE Location like '%Kenya%'
ORDER BY 1,2;

-- what country had the highest infection rate compared to population
SELECT Location, population,
       MAX(CAST(total_cases AS FLOAT)) AS HighestInfectionCount,
       MAX((CAST(total_cases AS FLOAT)/population)) * 100 AS PercentagePopulationInfected
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location, population
ORDER BY PercentagePopulationInfected DESC;

-- countries with the highest death count per population
SELECT Location, MAX(CAST(total_deaths AS int)) AS TotalDeathCount
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY Location
ORDER BY TotalDeathCount DESC;

-- we can also do a continental analysis/breakdown for highest death count
SELECT continent, MAX(CAST(total_deaths AS int)) AS TotalDeathCount
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;

-- GLOBAL NUMBERS
SELECT  
SUM(ISNULL(new_cases, 0)) AS TotalNewCases, 
SUM(ISNULL(new_deaths, 0)) AS TotalNewDeaths, 
CASE 
	WHEN SUM(ISNULL(new_cases, 0)) = 0 THEN 0
	ELSE (SUM(ISNULL(new_deaths, 0))/SUM(ISNULL(new_cases, 0)))*100 
	END AS GlobalDeathPercentage
FROM covid_data_project..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2;

-- used ISNULL to get rid of this error 'Divide by zero error encountered. Warning: Null value is eliminated by an aggregate or other SET operation.

-- MOVING ON TO THE SECOND TABLE: CovidVaccinations
-- joining the two tables

SELECT *
FROM covid_data_project..CovidDeaths deaths
JOIN covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date;

-- total population v vaccinations
SELECT deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations
FROM covid_data_project..CovidDeaths deaths
JOIN covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date
WHERE deaths.continent IS NOT NULL
ORDER BY 1,2,3;

-- farther calculations
SELECT deaths.continent, deaths.Location, deaths.date, deaths.population, vaccs.new_vaccinations, 
	SUM(CAST(ISNULL(vaccs.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY deaths.Location ORDER BY deaths.Location, 
	deaths.date) AS RollingPeopleVaccinated
FROM covid_data_project..CovidDeaths deaths
JOIN covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date
WHERE deaths.continent IS NOT NULL
ORDER BY 1,2,3;

-- the bigint function prevents the stack overflow error: Arithmetic overflow error converting expression to data type int. Warning: Null value is eliminated by an aggregate or other SET operation.
-- additionally, ISNULL helps eliminate null values in the new_vaccinations column
-- we can also use CONVERT to transform the new_vaccinations column to a different data type 

-- Percentage of rolling people vaccinated v population using Common Table Expression and Subquery
-- first using CTE
WITH PopulationVaccination AS (
	SELECT
		deaths.continent,
		deaths.Location,
		deaths.date,
		deaths.population,
		vaccs.new_vaccinations,
		SUM(CAST(ISNULL(vaccs.new_vaccinations, 0) AS bigint))
			OVER (PARTITION BY deaths.Location ORDER BY deaths.date) AS 
			RollingPeopleVaccinated
	FROM 
		covid_data_project..CovidDeaths deaths
	JOIN
		covid_data_project..CovidVaccinations vaccs
		ON deaths.Location = vaccs.Location
		AND deaths.date = vaccs.date
	WHERE
		deaths.continent IS NOT NULL
)
SELECT
	continent, 
	Location,
	date,
	population,
	new_vaccinations,
	RollingPeopleVaccinated,
	(RollingPeopleVaccinated / CAST(population AS float))*100 AS PercentagePeopleVaccinated
FROM 
	PopulationVaccination
ORDER BY
continent, Location, date;

-- alternatively
WITH PopvsVac (continent, date, Location, population, new_vaccinations, RollingPeopleVaccinated) 
AS (
SELECT deaths.continent, deaths.Location, deaths.date, deaths.population, vaccs.new_vaccinations, 
	SUM(CAST(ISNULL(vaccs.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY deaths.Location ORDER BY deaths.Location, 
	deaths.date) AS RollingPeopleVaccinated
FROM covid_data_project..CovidDeaths deaths
JOIN covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date
WHERE deaths.continent IS NOT NULL)
SELECT* , (RollingPeopleVaccinated/population) * 100 AS PercentagePeopleVaccinated
FROM PopvsVac;

-- Using Temp Table
DROP TABLE IF EXISTS #PercentagePeopleVaccinated;
CREATE TABLE #PercentagePeopleVaccinated(
	continent nvarchar(255),
	Location nvarchar(255),
	Date datetime,
	Population numeric,
	New_vaccinations numeric,
	RollingPeopleVaccinated numeric);

INSERT INTO #PercentagePeopleVaccinated
	SELECT deaths.continent, deaths.Location, deaths.date, deaths.population, vaccs.new_vaccinations, 
	SUM(CAST(ISNULL(vaccs.new_vaccinations, 0) AS bigint)) OVER (PARTITION BY deaths.Location ORDER BY deaths.Location, 
	deaths.date) AS RollingPeopleVaccinated
FROM covid_data_project..CovidDeaths deaths
JOIN covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date
WHERE deaths.continent IS NOT NULL;
--ORDER BY 1,2,3;

SELECT* , (RollingPeopleVaccinated/population) * 100 AS PercentagePeopleVaccinated
FROM #PercentagePeopleVaccinated;

-- visualisation yyyeeey
-- creating view to store data for later visualisations
IF OBJECT_ID('PercentagePeopleVaccinated', 'V') IS NOT NULL
DROP VIEW PercentagePeopleVaccinated;
GO

CREATE VIEW PercentagePeopleVaccinated AS
SELECT 
	deaths.continent, 
	deaths.Location, 
	deaths.date, 
	deaths.population, 
	vaccs.new_vaccinations, 
	SUM(CAST(ISNULL(vaccs.new_vaccinations, 0) AS bigint)) 
		OVER (PARTITION BY deaths.Location ORDER BY deaths.date) AS RollingPeopleVaccinated
FROM 
	covid_data_project..CovidDeaths deaths
JOIN 
	covid_data_project..CovidVaccinations vaccs
	ON deaths.location = vaccs.location
	AND deaths.date = vaccs.date
WHERE 
	deaths.continent IS NOT NULL;
GO

SELECT * FROM PercentagePeopleVaccinated;