
import numpy as np
import matplotlib.pyplot as plt

def extract_and_split_data_from_csv(file_path, num_of_algs, sweep_increment_length):
    with open(file_path, 'r') as file:
        # Read all lines from the file
        lines1 = file.readlines()
        # Extract the last row starting from the second column
        last_row = lines1[-1].strip().split(',')[1::1]
        # Convert the values to floats (assuming they are numerical)
        last_row_values = [1 * float(value.replace('"', '')) for value in last_row]

    all_scores_set = last_row_values[1::2]
    num_of_sub_groups = num_of_algs * sweep_increment_length
    scores_sub_groups = divide_into_groups(all_scores_set, num_of_sub_groups,1)



    return all_scores_set

def divide_into_groups(lst, num_groups, group_size):
    groups = []
    for i in range(num_groups):
        start_index = i * group_size
        end_index = start_index + group_size
        groups.append(lst[start_index:end_index])
    return groups


def create_score_plot(x_values, score_data, extra_info):
    fig, ax = plt.subplots(figsize=(12, 8))


    for i in range(len(score_data)):
        plt.errorbar(x_values, score_data[i], yerr = 0, fmt = 'o', label=f'{extra_info[i]}', color=colors[i],
                linestyle='-')

    x_values_inc = np.array(list(range(10, 110, 10)))
    plt.ylabel('Scores')
    plt.title(f'Scoring Plots  - {extra_info[0]} ')
    plt.xlabel('Number of Hunters')
    ax.set_xticks(ticks=x_values_inc, labels=x_values_inc, rotation=0)
    ax.set_ylim(0, 1)
    plt.yticks(np.arange(0, 1.1, 0.1))  # Create ticks at 0.1 intervals
    plt.legend()
    ax.grid(True)



file_paths = []
extra_info = []

file_paths.append('/Users/rvega/Catch_the_Boat Scoring_parameter_sweep-spreadsheet_test1.csv')
extra_info.append('100% Diffusing and Chasing')

file_paths.append('/Users/rvega/Catch_the_Boat Scoring_parameter_sweep-spreadsheet_test2_half-non-chasers.csv')
extra_info.append('100% Diffusing, only 50% Chasing')



num_of_algs = 1 # you can run more than one stategy at a time in Netlogo's Behavior Space that outputs into the same csv
x_values = np.array(list(range(2,102, 2))) # enter the range of the number of hunters (or whatever you are sweeping across) from the starting to the end + one increment value
                                            # for example, I swept through 2 to 100 hunters in increments of 2.
sweep_increment_length = len(x_values)
score_data = []
colors = ['green', 'purple', 'orange', 'blue', 'red', 'brown', 'teal']
for i in range(len(extra_info)):
    score_data.append(extract_and_split_data_from_csv(file_paths[i], num_of_algs, sweep_increment_length))

create_score_plot(x_values, score_data, extra_info)

plt.show()


