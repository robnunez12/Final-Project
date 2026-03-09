# Predicting NFL Game Totals with Betting Lines, Weather, and Stadium Context

## Project Overview

This project explores whether NFL game scoring can be predicted using a combination of betting market expectations, weather conditions, and stadium environment.

The primary objective is to model **total points scored in an NFL game** and evaluate whether environmental factors improve predictive performance beyond the baseline information already captured in Vegas betting lines.

The analysis combines multiple datasets including game results, stadium characteristics, weather data, and betting market information.

---

## Target Audience

This analysis is designed for:

- sports bettors
- sports analysts
- data scientists interested in sports analytics

Understanding which factors influence game scoring can help analysts interpret betting lines and evaluate how contextual variables such as weather may affect game outcomes.

---

## Key Research Question

**Do weather conditions and stadium environment improve our ability to predict NFL game totals beyond what is already captured by Vegas betting lines?**

---

## Data Sources

The project combines multiple datasets:

- **games.csv** – game-level results including teams and scores
- **stadiums.csv** – stadium characteristics including indoor/outdoor status
- **weather.csv** – weather conditions during games
- **betting_data.csv** – Vegas betting lines for game totals and spreads
- **teams.csv** – team lookup table

These datasets are merged using a shared `game_id` field to create a unified modeling dataset.

---

## Methods

### Data Processing

The datasets are merged into a single analysis dataframe and validated using:

- dataset shape checks
- duplicate detection
- missing value checks
- column validation

---

### Exploratory Data Analysis

Exploratory analysis examines how scoring varies across different environments.

Key comparisons include:

- Indoor vs outdoor stadium scoring
- Rain vs dry conditions
- Snow vs no snow
- Temperature ranges
- High wind conditions

Visualizations include:

- scatter plots
- histograms
- boxplots
- regression plots

---

### Modeling Approach

Two regression models are constructed:

**1. Baseline Model**

Predicts total points using only the Vegas betting total.

**2. Full Model**

Includes additional predictors:

- Vegas total line
- wind speed
- temperature
- rain indicator
- snow indicator
- indoor stadium indicator
- betting spread

Models are evaluated using:

- Mean Absolute Error (MAE)
- Root Mean Squared Error (RMSE)
- R-squared

---

## Key Findings

1. **Vegas betting lines are the strongest predictor of NFL game totals.**

2. **Weather variables provide only modest incremental predictive value.**

3. **Wind speed appears to have the most noticeable environmental effect on scoring.**

4. **Indoor stadiums tend to produce slightly higher scoring games.**

Overall, betting markets appear to already incorporate much of the information relevant to predicting scoring outcomes.
