rm(list = ls())
set.seed(3)
library(nflfastR)
library(tidyverse)

pbp_r <- load_pbp(2016:2022)

#filtering for running plays and plays w/o rushers out and then making missing rushigng yards to 0
pbp_r_run <- 
  pbp_r |>
  filter(play_type == "run" & !is.na(rusher_id)) |>
  mutate(rushing_yards = ifelse(is.na(rushing_yards), 0, rushing_yards))

#plotting a scatterplot (geom_point) of the data prior to building model and adding a smoothed line
#to see if it is positive or negative slope
ggplot(pbp_r_run, aes(x = ydstogo, y = rushing_yards)) +
  geom_point() + 
  theme_bw() + 
  stat_smooth(method = "lm")


#average over each yds per carry value gained in each bin
#first create ypc (yards per carry) 
pbp_r_run_avg <- 
  pbp_r_run |>
  group_by(ydstogo) |>
  summarize(ypc = mean(rushing_yards))

#plotting histogram with yards to go and yards per carry
ggplot(pbp_r_run_avg, aes(x = ydstogo, y = ypc)) +
  geom_point() + 
  theme_bw() +
  stat_smooth(method = "lm")

#creating simple linear regression model
yards_to_go_r <- 
  lm(rushing_yards ~ ydstogo, data = pbp_r_run)
summary(yards_to_go_r)

#creating an RYOE (rush yds over expected) column in the data
pbp_r_run <-
  pbp_r_run |>
  mutate(ryoe = resid(yards_to_go_r))

#grouping by seasons, rusher, rusher_id
#summarizing n = n() - number of carries a rusher has
# sum of ryoe - total ryoe
#mean of ryoe - ryoe per carry
#mean of rushing yards is ypc
#arrange by total ryoe from greatest to least
#then filtering to include only players with at least 50 carries

ryoe_r <- 
  pbp_r_run |>
  group_by(season, rusher_id, rusher) |>
  summarize(
    n=n(),
    ryoe_total = sum(ryoe),
    ryoe_per = mean(ryoe),
    yards_per_carry = mean(rushing_yards)
  ) |>
  arrange(-ryoe_total) |>
  filter(n > 50)
print(ryoe_r)

ryoe_r |>
  arrange(-ryoe_per)

#comparing ryoe per carry to traditional yards per carry
#creating current df to work with
ryoe_now_r <-
  ryoe_r |>
  select(-n, -ryoe_total)

#creating last seaon df and add 1 to season
ryoe_last_r <-
  ryoe_r |>
  select(-n, -ryoe_total) |>
  mutate(season = season +1) |>
  rename(ryoe_per_last = ryoe_per,
         yards_per_carry_last = yards_per_carry)

#join the 2 together
ryoe_lag_r <-
  ryoe_now_r |>
  inner_join(ryoe_last_r,
             by = c("rusher_id", "rusher", "season")) |>
  ungroup()
ryoe_lag_r
#selecting the two yds per carries columns and examining correlation
ryoe_lag_r |>
  select(yards_per_carry, yards_per_carry_last) |>
  cor(use = "complete.obs")

ryoe_lag_r |>
  select(ryoe_per, ryoe_per_last) |>
  cor(use = "complete.obs")


### EXERCISES
#1. What happens if you repeat the correlation analysis with 100 carries
#   as the threshold? What happens to the differences in r values?

# As seen in the code below, the correlation between last years yards per
# carry and this years compared to the correlation between last years
# rushing yards over expected with this years is closer when looking at
# a 100 carry threshold with a 1.43% difference. But rushing yards over
# expected is still more correlated when looking at the previous year.
ryoe_r_Q1 <- 
  pbp_r_run |>
  group_by(season, rusher_id, rusher) |>
  summarize(
    n=n(),
    ryoe_total = sum(ryoe),
    ryoe_per = mean(ryoe),
    yards_per_carry = mean(rushing_yards)
  ) |>
  arrange(-ryoe_total) |>
  filter(n > 100)
print(ryoe_r_Q1)

ryoe_r_Q1 |>
  arrange(-ryoe_per)

#comparing ryoe per carry to traditional yards per carry
#creating current df to work with
ryoe_now_r_Q1 <-
  ryoe_r_Q1 |>
  select(-n, -ryoe_total)

#creating last seaon df and add 1 to season
ryoe_last_r_Q1 <-
  ryoe_r_Q1 |>
  select(-n, -ryoe_total) |>
  mutate(season = season +1) |>
  rename(ryoe_per_last = ryoe_per,
         yards_per_carry_last = yards_per_carry)

#join the 2 together
ryoe_lag_r_Q1 <-
  ryoe_now_r_Q1 |>
  inner_join(ryoe_last_r_Q1,
             by = c("rusher_id", "rusher", "season")) |>
  ungroup()

#selecting the two yds per carries columns and examining correlation
ryoe_lag_r_Q1 |>
  select(yards_per_carry, yards_per_carry_last) |>
  cor(use = "complete.obs")

ryoe_lag_r_Q1 |>
  select(ryoe_per, ryoe_per_last) |>
  cor(use = "complete.obs")

#Question 2. Assume all of Alstott's carries were on third down and 1
#yard to go and all of Dunn's carries came on first down and 10 yards
#to go. Is that enough to explain the discrepancy in their yards per 
#carry values?
#Yes, that would be the case because it can be seen in the code above
#that the linear regression model shows us that yards to go has a 
#positive intercept in predicting rushing yards. This means that the
#more yards to there are to go we have a +.13 slope to then be multiplied
#by the amount of yards to go.