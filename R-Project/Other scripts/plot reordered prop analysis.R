library(ggplot2)
library(dplyr)
library(tidyr)
library(tibble)

# Interactive file selection
cat("Please select the Control CSV file...\n")
path1 <- file.choose()
cat("Selected Control file:", path1, "\n")

cat("Please select the T1D CSV file...\n")
path2 <- file.choose()
cat("Selected T1D file:", path2, "\n")

# If you need to skip headers or select specific columns:
control <- read.csv(path1, header = TRUE)  # or header = FALSE if no headers
t1d <- read.csv(path2, header = TRUE)

# If you need specific columns (equivalent to Excel range):
control <- read.csv(path1)[, c(8, 9)]  # columns H and I (8th and 9th columns)
t1d <- read.csv(path2)[, c(8, 9)]

# Clean and convert data to numeric (essential for CSV files)
# Remove any non-numeric characters and convert to numeric
control[, 2] <- as.numeric(gsub("[^0-9.-]", "", as.character(control[, 2])))
t1d[, 2] <- as.numeric(gsub("[^0-9.-]", "", as.character(t1d[, 2])))

# Remove rows with NA values after conversion
control <- control[complete.cases(control), ]
t1d <- t1d[complete.cases(t1d), ]

# Debug: Check raw data structure
cat("Raw data inspection:\n")
cat("Control data:\n")
print(control)
cat("\nT1D data:\n")
print(t1d)
cat("\nControl data structure:\n")
str(control)
cat("\nT1D data structure:\n")
str(t1d)

# Prepare data for plotting
control$group <- "Control"
t1d$group <- "T1D"


# Combine datasets
combined_data <- rbind(control, t1d)

# Check the data structure and handle accordingly
cat("Combined data structure:\n")
print(str(combined_data))
cat("Column names:", colnames(combined_data), "\n")
cat("Number of columns:", ncol(combined_data), "\n")

# Handle data reshaping based on structure
if(ncol(combined_data) == 3) {  # Assuming: classification, value, group
  colnames(combined_data)[1:2] <- c("classification", "value")
  combined_data_long <- combined_data
} else {
  # For wide format data where columns represent different classifications
  # Remove the group column temporarily for reshaping
  control_wide <- control %>% select(-group)
  t1d_wide <- t1d %>% select(-group)
  
  # Get the column names (these should be the classifications)
  classification_cols <- colnames(control_wide)
  
  control_long <- control_wide %>%
    mutate(sample_id = row_number()) %>%
    pivot_longer(cols = all_of(classification_cols), 
                 names_to = "classification", 
                 values_to = "value") %>%
    mutate(group = "Control") %>%
    select(-sample_id)
  
  t1d_long <- t1d_wide %>%
    mutate(sample_id = row_number()) %>%
    pivot_longer(cols = all_of(classification_cols), 
                 names_to = "classification", 
                 values_to = "value") %>%
    mutate(group = "T1D") %>%
    select(-sample_id)
  
  combined_data_long <- rbind(control_long, t1d_long)
}

# Calculate means for each classification and group
summary_data <- combined_data_long %>%
  group_by(classification, group) %>%
  summarise(
    mean_value = mean(value, na.rm = TRUE),
    se = sd(value, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# For count data, we need to calculate proportions and use appropriate tests
# First, calculate total counts for each group
cat("Debug: Checking combined_data_long structure:\n")
print(head(combined_data_long))
cat("Column names in combined_data_long:", colnames(combined_data_long), "\n")

# Check if we have an "all" classification
all_classifications <- unique(combined_data_long$classification)
cat("All classifications found:", all_classifications, "\n")

if("all" %in% all_classifications) {
  total_counts <- combined_data_long %>%
    filter(classification == "all") %>%
    select(group, value) %>%
    rename(total = value) %>%
    mutate(total = as.numeric(as.character(total)))  # Ensure total is numeric
  
  cat("Total counts data:\n")
  print(total_counts)
  
  # Calculate proportions for non-"all" classifications
  non_all_data <- combined_data_long %>%
    filter(classification != "all") %>%
    mutate(value = as.numeric(as.character(value)))  # Ensure value is numeric
  
  cat("Non-all data structure:\n")
  print(head(non_all_data))
  
  # Alternative join method - merge instead of left_join
  proportion_data <- merge(non_all_data, total_counts, by = "group", all.x = TRUE) %>%
    filter(!is.na(value) & !is.na(total) & total > 0) %>%  # Remove invalid data
    mutate(proportion = value / total)
    
} else {
  # If no "all" classification, read totals directly from I2 (row 2, column 9)
  cat("No 'all' classification found. Reading totals from I2.\n")
  
  # Read total cell counts directly from row 2 (I2 in Excel)
  control_total_raw <- read.csv(path1)[2, 9]  # Row 2, Column I
  t1d_total_raw <- read.csv(path2)[2, 9]  # Row 2, Column I
  
  # Clean and convert totals to numeric
  control_total <- as.numeric(gsub("[^0-9.-]", "", as.character(control_total_raw)))
  t1d_total <- as.numeric(gsub("[^0-9.-]", "", as.character(t1d_total_raw)))
  
  # Create totals dataframe
  total_counts <- data.frame(
    group = c("Control", "T1D"),
    total = c(control_total, t1d_total)
  )
  
  cat("Totals from I3:\n")
  print(total_counts)
  
  # Calculate proportions for each classification
  proportion_data <- combined_data_long %>%
    mutate(value = as.numeric(as.character(value))) %>%
    filter(!is.na(value)) %>%
    merge(total_counts, by = "group") %>%
    mutate(proportion = value / total)
  
  cat("Proportion calculation example:\n")
  print(head(proportion_data))
}

# Update summary data with proper percentages
summary_data <- proportion_data %>%
  group_by(classification, group) %>%
  summarise(
    count = sum(value),
    total = first(total),
    proportion = sum(value) / first(total),
    mean_value = proportion * 100,  # Convert to percentage
    se = sqrt(proportion * (1 - proportion) / first(total)) * 100,  # Standard error for proportion
    .groups = "drop"
  )

# Perform proportion tests for each classification
classifications <- unique(proportion_data$classification)
t_test_results <- data.frame()

# Debug: Check data structure
cat("Proportion data check:\n")
print(head(proportion_data))
cat("\nClassifications found:", classifications, "\n")
cat("Summary data:\n")
print(summary_data)

for (class in classifications) {
  control_data <- proportion_data[proportion_data$classification == class & proportion_data$group == "Control", ]
  t1d_data <- proportion_data[proportion_data$classification == class & proportion_data$group == "T1D", ]
  
  if (nrow(control_data) > 0 && nrow(t1d_data) > 0) {
    # Get count and total for each group
    control_count <- control_data$value[1]
    control_total <- control_data$total[1]
    t1d_count <- t1d_data$value[1]
    t1d_total <- t1d_data$total[1]
    
    # Calculate percentages
    control_percent <- (control_count / control_total) * 100
    t1d_percent <- (t1d_count / t1d_total) * 100
    
    cat("\nClassification:", class, "\n")
    cat("Control:", control_count, "out of", control_total, "(", round(control_percent, 2), "%)\n")
    cat("T1D:", t1d_count, "out of", t1d_total, "(", round(t1d_percent, 2), "%)\n")
    
    tryCatch({
      # Use prop.test for comparing proportions (most appropriate for count data)
      prop_test <- prop.test(c(control_count, t1d_count), c(control_total, t1d_total), 
                            alternative = "two.sided", correct = TRUE)
      
      # For t-test, we'll compare the raw percentages as single values
      # This is less appropriate than prop.test for count data, but included as requested
      control_percent_value <- control_percent
      t1d_percent_value <- t1d_percent
      
      # Since we only have single percentage values per group, we'll use a simpler approach
      # Create vectors with the percentage repeated according to some reasonable sample size
      # or use the actual counts to create binary data for t-test
      
      # Method: Create binary data (0s and 1s) based on counts
      control_binary <- c(rep(1, control_count), rep(0, control_total - control_count))
      t1d_binary <- c(rep(1, t1d_count), rep(0, t1d_total - t1d_count))
      
      # Perform unpaired, two-sided t-test on binary data
      t_test <- t.test(control_binary, t1d_binary, 
                      paired = FALSE, alternative = "two.sided", var.equal = FALSE)
      
      # Use prop.test p-value as primary (more appropriate for proportions)
      primary_p_value <- prop_test$p.value
      
      # Determine significance level
      if (primary_p_value < 0.001) {
        significance <- "***"
      } else if (primary_p_value < 0.01) {
        significance <- "**"
      } else if (primary_p_value < 0.05) {
        significance <- "*"
      } else {
        significance <- "ns"
      }
      
      t_test_results <- rbind(t_test_results, data.frame(
        classification = class,
        p_value = primary_p_value,
        prop_test_p = prop_test$p.value,
        t_test_p = t_test$p.value,
        significance = significance
      ))
      
      cat("Proportion test p-value:", round(prop_test$p.value, 6), "\n")
      cat("Student's t-test p-value:", round(t_test$p.value, 6), "\n")
      cat("Comparing:", round(control_percent, 2), "% (Control) vs", round(t1d_percent, 2), "% (T1D)\n")
    }, error = function(e) {
      cat("Statistical tests failed for", class, ":", e$message, "\n")
      
      # Add non-significant result for plotting
      t_test_results <<- rbind(t_test_results, data.frame(
        classification = class,
        p_value = NA,
        prop_test_p = NA,
        t_test_p = NA,
        significance = "ns"
      ))
    })
  } else {
    cat("Missing data for", class, "\n")
    
    # Add non-significant result for plotting
    t_test_results <- rbind(t_test_results, data.frame(
      classification = class,
      p_value = NA,
      prop_test_p = NA,
      t_test_p = NA,
      significance = "ns"
    ))
  }
}

# Add significance annotations to summary data
summary_data <- merge(summary_data, t_test_results, by = "classification", all.x = TRUE)

# Define the desired order for classifications
classification_order <- c("Num Negative", "Num 1+", "Num 2+", "Num 3+")

# Filter data to only include the desired classifications and reorder
filtered_summary_data <- summary_data %>%
  filter(classification %in% classification_order) %>%
  mutate(classification = factor(classification, levels = classification_order, 
                                labels = c("Negative", "1+", "2+", "3+")))

# Filter statistical results for the same classifications
filtered_t_test_results <- t_test_results %>%
  filter(classification %in% classification_order) %>%
  mutate(classification = factor(classification, levels = classification_order,
                                labels = c("Negative", "1+", "2+", "3+")))

# Calculate position for significance stars (above the higher bar)
max_values <- filtered_summary_data %>%
  group_by(classification) %>%
  summarise(max_y = max(mean_value + se) * 1.1, .groups = "drop")

significance_data <- merge(filtered_t_test_results, max_values, by = "classification")

# Create the barplot
p <- ggplot(filtered_summary_data, aes(x = classification, y = mean_value, fill = group)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(aes(ymin = mean_value - se, ymax = mean_value + se), 
                position = position_dodge(width = 0.8), width = 0.2) +
  geom_text(data = significance_data, 
            aes(x = classification, y = max_y, label = significance),
            inherit.aes = FALSE, hjust = 0.5, vjust = 0, size = 5) +
  scale_fill_manual(values = c("Control" = "lightblue", "T1D" = "lightcoral")) +
  labs(
    title = "mIR-155 expression",
    x = NULL,
    y = "Percentage (%)",
    fill = "Group"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(hjust = 0.5)
  )

# Display the plot
print(p)

# Print statistical test results
cat("\nStatistical test results for selected classifications:\n")
cat("prop_test_p: Proportion test (most appropriate for count data)\n")
cat("t_test_p: Student's t-test (unpaired, two-sided)\n")
print(filtered_t_test_results)


