module DiscgolfRecord

using CSV, DataFrames, Distances, DataStructures, JSON, Dates, TOML, LightXML

export preview_course, COURSES

COURSES_DIR = "data/courses/"

struct Location
    lat::Float64
    lon::Float64
end
Location(d::AbstractDict) = Location(d["lat"], d["lon"])
lat(l::Location) = l.lat
lon(l::Location) = l.lon

struct Tee
    id::String
    loc::Location
end
loc(t::Tee) = t.loc
id(p::Tee) = p.id
lat(p::Tee) = lat(loc(p))
lon(p::Tee) = lon(loc(p))

struct Pin
    id::String
    loc::Location
end
loc(p::Pin) = p.loc
id(p::Pin) = p.id
lat(p::Pin) = lat(loc(p))
lon(p::Pin) = lon(loc(p))

struct Hole
    id::String
    tees::Vector{Tee}
    pins::Vector{Pin}
    pars::Dict{String,Dict{String, Int}}
end
tees(h::Hole) = h.tees
pins(h::Hole) = h.pins
id(h::Hole) = h.id
pars(h::Hole) = h.pars
function par(h::Hole,t,p)
    temp = pars(h)[id(t)]
    temp[id(p)]
end

struct Course
    id::String
    name::String
    loc::Location
    holes::Vector{Hole}
end
loc(c::Course) = c.loc
id(c::Course) = c.id
holes(c::Course) = c.holes
name(c::Course) = c.name
lat(c::Course) = lat(loc(c))
lon(c::Course) = lon(loc(c))

struct Throw
    loc1::Location
    loc2::Location
    type::String
    res::String
    pin::Pin
end

struct PlayedHole
    hole::Hole
    tee::Tee
    pin::Pin
    throws::Vector{Throw}
    res::Int
end

struct Round
    id::String
    label::String
    notes::String
    time::String
    course::Course
    holes::Vector{PlayedHole}
end
#get_scorecard(r::Round)
#make_vis(r::Round)

function read_round(input_csv, label, notes)
    
    Round(id, label, time, course, holes, notes)
end

function make_preview(r::Round, preview_file)
    return -1
end

function dg_preview(input_csv; preview_file = "preview.kml")
    
    round = make_round(input_csv)
    make_preview(round, preview_file)

end


function read_courses_dir(courses_dir = COURSES_DIR)
    files = readdir(courses_dir)

    D = Dict()
    for f in files
        d = JSON.parsefile(joinpath(courses_dir, f), dicttype=OrderedDict)
        c = process_course_dict(d)
        D[id(c)] = c
    end
    
    D
end

function process_course_dict(d)
    id = d["id"]
    name = d["name"]
    loc = Location(d["loc"])

    holes = Hole[]
    for (k,v) in d["holes"]
        h_id = String(k)

        pins = Pin[]
        for (kk,vv) in v["pins"]
            push!(pins, Pin(String(kk), Location(vv)))
        end

        tees = Tee[]
        for (kk,vv) in v["tees"]
            push!(tees, Tee(String(kk), Location(vv)))
        end

        ###make pars
        pars = Dict{String,typeof(Dict{String, Int}())}()
        for (kk,vv) in v["pars"]
            ppars = Dict{String, Int}()
            for (kkk,vvv) in vv
                ppars[kkk] = vvv
            end
            pars[kk] = ppars
        end

        push!(holes, Hole(h_id, tees, pins, pars))

    end

    Course(id, name, loc, holes)
end

function course_kml(c::Course)
    l = ["""<?xml version="1.0" encoding="UTF-8"?>"""]
    push!(l, """<kml xmlns="http://www.opengis.net/kml/2.2">""")
    push!(l, " <Document>")
    
    push!(l, """  <Style id="tee_style">""")
    push!(l, "   <IconStyle>")
    push!(l, "    <Icon>")
    push!(l, "     <href>http://maps.google.com/mapfiles/kml/paddle/grn-blank.png</href>")
    push!(l, "    </Icon>")
    push!(l, "   </IconStyle>")
    push!(l, "  </Style>")
    
    push!(l, """  <Style id="pin_style">""")
    push!(l, "   <IconStyle>")
    push!(l, "    <Icon>")
    push!(l, "     <href>http://maps.google.com/mapfiles/kml/paddle/blu-blank.png</href>")
    push!(l, "    </Icon>")
    push!(l, "   </IconStyle>")
    push!(l, "  </Style>")

    push!(l, """  <Style id="par_3_style">""")
    push!(l, "   <LineStyle>")
    push!(l, "    <width>1</width>")
    push!(l, "   </LineStyle>")
    push!(l, "  </Style>")

    push!(l, """  <Style id="par_not3_style">""")
    push!(l, "   <LineStyle>")
    push!(l, "    <color>ff00ffff</color>")
    push!(l, "    <width>1.5</width>")
    push!(l, "   </LineStyle>")
    push!(l, "  </Style>")

    push!(l, "  <Placemark>")
    push!(l, "   <name>$(name(c))</name>")
    push!(l, "   <Point>")
    push!(l, "    <coordinates>$(lon(c)),$(lat(c)),0</coordinates>")
    push!(l, "   </Point>")
    push!(l, "  </Placemark>")

    #Lets draw all the teepads and pins, and lines that connect them all!
    for h in holes(c)
        for p in pins(h)
            push!(l, "  <Placemark>")
            push!(l, "   <name>$(id(h) * id(p))</name>")
            push!(l, "   <styleUrl>#pin_style</styleUrl>")
            push!(l, "   <Point>")
            push!(l, "    <coordinates>$(lon(p)),$(lat(p)),0</coordinates>")
            push!(l, "   </Point>")
            push!(l, "  </Placemark>")
        end

        for t in tees(h)
            push!(l, "  <Placemark>")
            push!(l, "   <name>$(id(h) * id(t))</name>")
            push!(l, "   <styleUrl>#tee_style</styleUrl>")
            push!(l, "   <Point>")
            push!(l, "    <coordinates>$(lon(t)),$(lat(t)),0</coordinates>")
            push!(l, "   </Point>")
            push!(l, "  </Placemark>")
        end

        for  t in tees(h), p in pins(h)

            push!(l, "  <Placemark>")
            push!(l, "   <name> Hole $(id(h)), $(id(t)) ->  $(id(p))</name>")
            
            if par(h,t,p) == 3
                push!(l, "   <styleUrl>#par_3_style</styleUrl>")
            else
                push!(l, "   <styleUrl>#par_not3_style</styleUrl>")
            end

            push!(l, "   <LineString>")
            push!(l, "    <coordinates>")
            push!(l, "     $(lon(t)),$(lat(t))")
            push!(l, "     $(lon(p)),$(lat(p))")
            push!(l, "    </coordinates>")
            push!(l, "   </LineString>")
            push!(l, "  </Placemark>")
        end

    end
    
    push!(l, " </Document>")
    push!(l, "</kml>")
    l
end

function preview_course(c::Course)
    kml = course_kml(c)
    filename = id(c) * "_preview.kml"
    open(filename,"w") do f
        for line in kml
            println(f, line)
        end
    end
end

const COURSES = read_courses_dir()
const CONFIG = TOML.parsefile("my_config.toml")




"""
    interpolate_gpx(gpx_file, times) -> Vector{Location}
    
Interpolates a gpx file at the given timestamps 
"""
function interpolate_gpx(gpx_file, times)
    dfmt = DateFormat("y-m-d H:M:S")
    ts_df = CSV.read(times, DataFrame, datarow=2, header=[:time, :disc], dateformat=dfmt)


    
end

function make_round_csv(timestamp_file, tracking_file)
    interpolate_gpx(tracking_file, timestamp_file)
end
















#Utilities

function make_course_json(tees_file, pins_file, label, name, loc)

    warning("Note, par is initialized to 3 for all hole combinations. Edit resulting json manually.")

    holes_dict = OrderedDict()

    tees_df = CSV.read(tees_file, DataFrame)
    pins_df = CSV.read(pins_file, DataFrame)

    hole_nums = unique(tees_df.hole)
    for h in hole_nums
        hole_dict = OrderedDict()
        
        td = OrderedDict()
        for r in eachrow(tees_df)
            if r.hole == h
                ismissing(r.variation) ? key = "" : key = r.variation 
                td[key] = OrderedDict(:lat => r.lat, :lon => r.lon)
            end
        end
        hole_dict[:tees] = td

        pd = OrderedDict()
        for r in eachrow(pins_df)
            if r.hole == h
                ismissing(r.variation) ? key = "" : key = r.variation
                pd[key] = OrderedDict(:lat => r.lat, :lon => r.lon)
            end
        end
        hole_dict[:pins] = pd

        sd = OrderedDict()
        for r in eachrow(tees_df)
            if r.hole == h
                ismissing(r.variation) ? key = "" : key = r.variation 
                
                sdd = OrderedDict()
                for rr in eachrow(pins_df)
                    if rr.hole == h
                        ismissing(rr.variation) ? key2 = "" : key2 = rr.variation
                        sdd[key2] = 3
                    end
                end

                sd[key] = sdd
            end
        end
        hole_dict[:pars] = sd
        
        holes_dict[h] = hole_dict
    end

    D = OrderedDict()
    D[:id] = label
    D[:name] = name
    D[:loc] = OrderedDict(:lat => loc[1], :lon => loc[2])
    D[:holes] = holes_dict

    open("$label.json", "w") do f
        JSON.print(f, D, 2)
    end

end


end
