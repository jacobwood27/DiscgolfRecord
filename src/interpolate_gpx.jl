#!/usr/bin/env julia

using LightXML, CSV, DataFrames, TimeZones, Dates, ArgParse
using Interpolations: LinearInterpolation

function read_gpx(gpx_file)
    xdoc = parse_file(gpx_file)
    xroot = root(xdoc)  # an instance of XMLElement
    trkpts = xroot["trk"][1]["trkseg"][1]["trkpt"]

    df = DataFrame(time=Dates.DateTime[], lat=Float64[], lon=Float64[])
    dfmt = DateFormat("y-m-dTH:M:S\\Z")
    # traverse all its child nodes and print element names
    for (i,t) in enumerate(trkpts) 
        ad = attributes_dict(t)
        tim = Dates.DateTime(content(t["time"][1]), dfmt)
        push!(df, [tim, parse(Float64,ad["lat"]), parse(Float64,ad["lon"])])
    end

    free(xdoc)
    df
end

function read_timestamp(timestamp_file)
    df = DataFrame(time=Dates.DateTime[], disc=String[])
    f=CSV.File(timestamp_file, delim=',', datarow=2, header=false)
    dfmt = DateFormat("yyyy-mm-ddTHH:MM:SSzzzz")
    for (i,r) in enumerate(f)
        t = DateTime(ZonedDateTime(r.Column1, dfmt),UTC)
        disc = r.Column2
        push!(df,[t, disc])
    end
    df
end

"""
    interpolate_gpx(gpx_file, times) -> Vector{Location}
    
Interpolates a gpx file at the given timestamps and writes out csv
"""
function interpolate_gpx(timestamp_file, gpx_file, out)

    ts_df = read_timestamp(timestamp_file)

    gpx_df = read_gpx(gpx_file)

    lat_i = LinearInterpolation(datetime2unix.(gpx_df.time), gpx_df.lat)
    lon_i = LinearInterpolation(datetime2unix.(gpx_df.time), gpx_df.lon)
    
    df = DataFrame(time=DateTime[], lat=Float64[], lon=Float64[], disc=String[])

    for r in eachrow(ts_df)
        lat = lat_i(datetime2unix(r.time))
        lon = lon_i(datetime2unix(r.time))
        push!(df, [r.time, lat, lon, r.disc])
    end

    df

    CSV.write(out, df)
    
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "csv"
            help = "Timestamp file"
            required = true
        "gpx"
            help = "Location recording file"
            required = true
        "--out"
            help = "Name of output file"
            default = "round_raw.csv"
    end
    return parse_args(s)
end

args = parse_commandline()

interpolate_gpx(args["csv"], args["gpx"], args["out"])