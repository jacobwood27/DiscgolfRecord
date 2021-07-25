using DiscgolfRecord
using Test

@testset "DiscgolfRecord.jl" begin
    # Write your tests here.

    # Make sure we can preview courses
    @test_nowarn preview_course(COURSES["kit_carson"])
    @test_nowarn preview_course(COURSES["mast_park"])

    # Test the round reader 
    sample_round_file = "20210719_mastpark.csv"
    @test_nowarn rnd = DiscgolfRecord.read_round(sample_round_file)


end
