# DiscgolfRecord


### How is this intended to be used?
 1. Place recording.gpx and timestamp.csv file into a directory
 2. Run process_round_recording.jl in that directory
 3. Hand edit the resulting round_raw.csv until the opened map looks good
 4. Run save_round.jl to copy the files and update the statistics appropriately
 5. Git add, commit, push the dg_stats dir
 
If course does not exist within 1km, a new course is guessed and initialized.
