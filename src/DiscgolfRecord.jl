module DiscgolfRecord

using CSV, DataFrames, Distances, DataStructures, JSON, TOML, LightXML, TimeZones, Dates
using Interpolations: LinearInterpolation

export guess_and_check, parse_round_raw_csv, id

STATS_DIR = joinpath(homedir(),"dg_stats")

COURSES_DIR = joinpath(@__DIR__,"..","data","courses")
DISCS_CSV = joinpath(@__DIR__,"..","data","discs.csv")
SCORE_NAMES = Dict(
    -3 => "ALBATROSS",
    -2 => "EAGLE",
    -1 => "BIRDIE",
    0 => "PAR",
    1 => "BOGEY",
    2 => "DOUBLE BOGEY",
    3 => "TRIPLE BOGEY",
    4 => "QUADRUPLE BOGEY")

struct Location
    lat::Float64
    lon::Float64
end
lat(l::Location) = l.lat
lon(l::Location) = l.lon
dist(l1::Location, l2::Location) = Distances.haversine((lon(l1),lat(l1)),(lon(l2), lat(l2)))
Location(v) = Location(v[1], v[2])

struct POI
    id::String
    loc::Location
end
empty_poi() = POI("",Location(0.0,0.0))
loc(p::POI) = p.loc
id(p::POI) = p.id
lat(p::POI) = lat(loc(p))
lon(p::POI) = lon(loc(p))
dist(p1::POI, p2::POI) = dist(loc(p1), loc(p2))
function get_elem(elem_id, V::Vector{POI})
    for v in V
        if id(v) == elem_id
            return v
        end
    end
    error("No element of name $elem_id")
end

struct Hole
    id::String
    tees::Vector{POI}
    pins::Vector{POI}
    pars::Dict{String,Dict{String, Int}}
end
empty_hole() = Hole("",[],[],Dict(""=>Dict(""=>0)))
tees(h::Hole) = h.tees
pins(h::Hole) = h.pins
id(h::Hole) = h.id
pars(h::Hole) = h.pars
par(h::Hole,tee::String,pin::String) = pars(h)[tee][pin]
par(h::Hole,tee::POI,pin::POI) = pars(h)[id(tee)][id(pin)]
get_pin(h::Hole, id::String) = get_elem(id,pins(h))
get_tee(h::Hole, id::String) = get_elem(id,tees(h))
get_pin(h::Hole, p::POI) = get_elem(id(p),pins(h))
get_tee(h::Hole, t::POI) = get_elem(id(t),tees(h))


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
tees(c::Course) = tees.(holes(c))
get_hole(c::Course, id::String) = get_elem(id,holes(c))

struct Throw
    loc1::Location
    loc2::Location
    type::String
    res::String
    pin::POI
    disc::String
end
loc1(t::Throw) = t.loc1 
loc2(t::Throw) = t.loc2 
lat(t::Throw) = lat(loc1(t))
lon(t::Throw) = lon(loc1(t))
disc(t::Throw) = t.disc

struct PlayedHole
    hole::Hole
    tee::POI
    pin::POI
    throws::Vector{Throw}
    res::Int
end
throws(ph::PlayedHole) = ph.throws
pin(ph::PlayedHole) = ph.pin
tee(ph::PlayedHole) = ph.tee
id(ph::PlayedHole) = id(ph.hole)
score(ph::PlayedHole) = length(throws(ph))
res(ph::PlayedHole) = ph.res
par(ph::PlayedHole) = par(ph.hole, ph.tee, ph.pin)
function res_name(ph::PlayedHole)
    if haskey(SCORE_NAMES, res(ph))
        return SCORE_NAMES[res(ph)]
    else
        return "BAD"
    end
end

struct Round
    id::String
    name::String
    notes::String
    start_time::DateTime
    end_time::DateTime
    course::Course
    holes::Vector{PlayedHole}
end
course(r::Round) = r.course
id(r::Round) = r.id
name(r::Round) = r.name
notes(r::Round) = r.notes
holes(r::Round) = r.holes
date(r::Round) = Dates.format(r.start_time,"yyyy-mm-dd")
score(r::Round) = sum([res(h) for h in holes(r)])
num_holes(r::Round) = length(holes(r))
par(r::Round) = sum([par(h) for h in holes(r)])
total(r::Round) = par(r) + score(r)

#get_scorecard(r::Round)
#make_vis(r::Round)

# function read_round(input_csv, label, notes)
    
#     Round(id, label, time, course, holes, notes)
# end

# function make_preview(r::Round, preview_file)
#     return -1
# end

# function dg_preview(input_csv; preview_file = "preview.kml")
    
#     round = make_round(input_csv)
#     make_preview(round, preview_file)

# end


function read_courses_dir(courses_dir = COURSES_DIR)
    files = readdir(courses_dir)

    C = Course[]
    for f in files
        d = JSON.parsefile(joinpath(courses_dir, f), dicttype=OrderedDict)
        c = process_course_dict(d)
        push!(C,c)
    end
    
    C
end

function process_course_dict(d)
    id = d["id"]
    name = d["name"]
    loc = Location(d["loc"])

    holes = Hole[]
    for (k,v) in d["holes"]
        h_id = String(k)

        pins = POI[]
        for (kk,vv) in v["pins"]
            push!(pins, POI(String(kk), Location(vv)))
        end

        tees = POI[]
        for (kk,vv) in v["tees"]
            push!(tees, POI(String(kk), Location(vv)))
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

function infer_course(l::Location, courses::Vector{Course})
    best_dist = 1000
    best_course = courses[1]

    for c in courses 
        this_dist = dist(l, loc(c))
        if this_dist < best_dist
            best_dist = this_dist
            best_course = c
        end
    end

    if best_dist > 999
        error("No courses found within 1 km.")
    end

    return best_course
    
end

function infer_tee(l::Location, c::Course)
    best_dist = 100
    best_hole = empty_hole()    #placeholder
    best_tee = empty_poi()      #placeholder
    for h in holes(c)
        for t in tees(h)
            this_dist = dist(l,loc(t))
            if this_dist < best_dist
                best_dist = this_dist
                best_hole = h
                best_tee = t
            end
        end
    end
    best_hole, best_tee, best_dist
end



function parse_round_raw_csv(round_raw_csv)
    
    COURSES = read_courses_dir()

    df = CSV.read(round_raw_csv, DataFrame)
    nrows = size(df,1)
    
    t_start = df[1,:time]
    t_end = df[end,:time]

    loc_i = Location(df[1,:lat], df[1,:lon])
    c = infer_course(loc_i, COURSES)

    PH = PlayedHole[]

    cutoff_dists = [10,10,20] #this is placeholder - should be a better way to do this

    #When we are just starting up, let's snag the teebox and the hole we are playing
    cur_i = 1
    h, t, _ = infer_tee(loc_i, c)

    completed_read = false

    # while !eof
    while ~completed_read

        #Now we need to find where the hole ends, this will happen when we mark near a pin of the current hole, and then near a tee of another hole, and then not near a tee of that hole
        p = empty_poi() #to overwrite
        next_t = empty_poi()
        next_h = empty_hole()
        idx = 0

        for i in cur_i:nrows-1

            r = df[i,:]
            this_loc = Location(r.lat, r.lon)
            pds = [dist(loc(p), this_loc) for p in pins(h)]
            pd, p_num = findmin(pds)
            p = pins(h)[p_num]

            if i==nrows-1
                idx = i+1
                completed_read = true
                break
            end

            n_r = df[i+1,:]
            n_loc = Location(n_r.lat, n_r.lon)
            next_h, next_t, bd = infer_tee(n_loc, c)

            nn_r = df[i+2,:]
            nn_loc = Location(nn_r.lat, nn_r.lon)
            ndd = dist(nn_loc, loc(next_t))

            if pd<cutoff_dists[1] && bd<cutoff_dists[2] && ndd>cutoff_dists[3] #then we have found the last putt of the hole!
                idx = i
                break
            end
        end
        

        #Now we know what throws were made on the hole, which teebox, and which pin. We can make some Throws and a PlayedHole!
        i1 = cur_i
        i2 = idx-1
        T = Throw[]
        for i in i1:i2
            loc1 = Location(df[i,:lat], df[i,:lon])
            loc2 = Location(df[i+1,:lat], df[i+1,:lon])
            if i==i1
                type = "DRIVE"
                loc1 = loc(t)
            else
                type = "THROW"
            end

            if i==i2
                res = "BASKET"
                loc2 = loc(p)
            else
                res = ""
            end

            pin = p
            disc = df[i,:disc]

            thrw = Throw(loc1, loc2, type, res, pin, disc)

            push!(T, thrw)
        end

        s = length(T) - par(h, t, p)
        ph = PlayedHole(h,t,p,T,s)
        push!(PH, ph)

        t = next_t
        h = next_h
        cur_i = idx+1

    end

    start_minute = Dates.format(t_start, "yyyy-mm-dd-HH-MM")
    round_id = start_minute * "_" * id(c)
    name = "Sample Name"
    notes = "Sample Notes"
    start_time = t_start
    end_time = t_end

    Round(round_id, name, notes, start_time, end_time, c, PH)
end


function guess_and_check(round_raw_csv, out="check_round.json")

    r = parse_round_raw_csv(round_raw_csv)
    
    df_raw = CSV.read(round_raw_csv, DataFrame)

    json_both = draw_both(r,df_raw)

    open(out, "w") do f
        JSON.print(f, json_both, 2)
    end

end

function draw_both(r::Round, df)
    D = OrderedDict()
    D["type"] = "FeatureCollection"

    #Some metadata up front
    my_discs = CSV.read(joinpath(STATS_DIR, "discs", "discs.csv"), DataFrame)
    discs = OrderedDict[]
    for r in eachrow(my_discs)
        push!(discs, OrderedDict(
            "id" => r.my_id,
            "image" => r.image
        ))
    end
    D["discs"] = discs

    summary = []
    running = 0
    for h in holes(r)
        running += res(h)
        h_summary = OrderedDict(
            "hole" => id(h),
            "tee" => id(tee(h)),
            "pin" => id(pin(h)),
            "par" => par(h),
            "score" => score(h),
            "running" => running
        )
        push!(summary, h_summary)
    end
    D["summary"] = summary


    features = OrderedDict[]

    #Now let's put all the raw marks on the map
    for row in eachrow(df)
        d = OrderedDict()
        d["type"] = "Feature"
        d["properties"] = OrderedDict(
            "thing" => "raw_mark",
            "disc_name" => row.disc,
            "name"  => "$(rownumber(row))"
            )
        d["geometry"] = OrderedDict(
                "type" => "Point",
                "coordinates" => [row.lon, row.lat]
            )
            push!(features, d)
    end

    #Now draw the course
    c = course(r)
    for h in holes(c)
        for t in tees(h)
            d = OrderedDict()
            d["type"] = "Feature"
            d["properties"] = OrderedDict(
                "thing" => "tee",
                "name"  => id(h) * id(t)
                )
            d["geometry"] = OrderedDict(
                "type" => "Point",
                "coordinates" => [lon(t), lat(t)]
            )
            push!(features, d)
        end

        for p in pins(h)
            d = OrderedDict()
            d["type"] = "Feature"
            d["properties"] = OrderedDict(
                "thing" => "pin",
                "name" => id(h) * id(p))
            d["geometry"] = OrderedDict(
                "type" => "Point",
                "coordinates" => [lon(p), lat(p)]
            )
            push!(features, d)
        end
    end

    #Now draw the throws as they were interpreted
    for h in holes(r)
        for t in h.throws
            d = OrderedDict()
            d["type"] = "Feature"
            d["properties"] = OrderedDict(
                "thing" => "throw",
                "hole_res" => h.res)
            d["geometry"] = OrderedDict(
                "type" => "LineString",
                "coordinates" => [[lon(loc1(t)), lat(loc1(t))],[lon(loc2(t)), lat(loc2(t))]]
            )
            push!(features, d)
        end
    end

    D["features"] = features

    D
end

feet(x) = round(x*3.2808)
llstring(x) = string(round(x, digits=5))

function append_all_throws!(df,r::Round)
    for h in holes(r)
        shot=0
        
        for t in throws(h)
            shot += 1

            if score(h) == 1
                t_res = "ACE"
            elseif shot == 1
                t_res = "DRIVE"
            elseif shot == score(h)
                t_res = "MAKE"
            else
                t_res = "THROW"
            end

            push!(df, (
                        date(r) |> string,
                        id(course(r)),
                        id(r),
                        id(h),
                        shot |> string,
                        disc(t),
                        lat(loc1(t)) |> llstring,
                        lon(loc1(t)) |> llstring,
                        lat(loc2(t)) |> llstring,
                        lon(loc2(t)) |> llstring,
                        lat(pin(h)) |> llstring,
                        lon(pin(h)) |> llstring,
                        dist(loc1(t), loc2(t)) |> feet |> string,
                        dist(loc1(t), loc(pin(h))) |> feet |> string,
                        res_name(h),
                        t_res)
                )
        end
    end
end

function append_all_holes!(df, r::Round)
    for h in holes(r)
        push!(df, (
                    date(r) |> string,
                    id(course(r)),
                    id(r),
                    id(h),
                    par(h) |> string,
                    id(tee(h)),
                    id(pin(h)),
                    dist(tee(h), pin(h)) |> feet |> string,
                    dist(loc1(throws(h)[1]), loc2(throws(h)[1])) |> feet |> string,
                    dist(loc1(throws(h)[end]), loc2(throws(h)[end])) |> feet |> string,
                    score(h) |> string,
                    res_name(h))
            )
    end
end

function append_round!(df, r::Round)
    push!(df, (
        date(r) |> string,
        id(course(r)),
        id(r),
        num_holes(r) |> string,
        par(r) |> string,
        total(r) |> string,
        score(r) |> string
    ))
end

function get_dash_json(throws_df, holes_df, rounds_df)
    D = OrderedDict()

    #Recent Scores
    recent_scores = OrderedDict()
    recent_scores["labels"] = rounds_df.date
    recent_scores["datasets"] = [OrderedDict(
        "label" => "Recent Scores",
        "data" => rounds_df.result,
        "backgroundColor" => "rgba(60,141,188,0.9)",
        "borderColor" => "rgba(60,141,188,0.8)",
        "pointRadius" => 5,
        "pointColor" => "#3b8bba",
        "pointStrokeColor" => "rgba(60,141,188,1)",
        "pointHighlightFill" => "#fff",
        "pointHighlightStroke" => "rgba(60,141,188,1)",
        "showLine" => true,
        "fill" => false
    )]
    D["recent_scores"] = recent_scores


    #Disc Bag
    my_discs = CSV.read(joinpath(STATS_DIR, "discs", "discs.csv"), DataFrame)
    discs_db = CSV.read(DISCS_CSV, DataFrame, type=String)
    all_discs = innerjoin(my_discs, discs_db, on = :disc_id => :id)
    discs = OrderedDict[]
    for r in eachrow(all_discs)
        push!(discs, OrderedDict(
            "id" => r.my_id,
            "image" => r.image,
            "mold" => "$(r.brand) $(r.mold)",
            "plastic" => r.plastic,
            "weight" => r.weight,
            "numbers" => "$(r.speed), $(r.glide), $(r.turn), $(r.fade)"
        ))
    end
    D["discs"] = discs


    #All Rounds
    rounds = OrderedDict[]
    COURSES = read_courses_dir()
    for r in eachrow(rounds_df)
        c_name = "Unknown"
        for c in COURSES
            if r.course == id(c)
                c_name = name(c)
                break
            end
        end
        push!(rounds, OrderedDict(
            "id" => r.round,
            "date" => r.date,
            "course" => c_name,
            "result" => r.result
        ))
    end
    D["rounds"] = rounds

    D
end

function save_round(round_raw_csv)

    r = parse_round_raw_csv(round_raw_csv)

    #write out round.json

    #append all throws to all_throws.csv
    throws_csv = joinpath(STATS_DIR,"stats","all_throws.csv")
    throws_df = CSV.read(throws_csv, DataFrame, type=String)
    append_all_throws!(throws_df,r)
    CSV.write(throws_csv, throws_df)

    #append all holes to all_holes.csv
    holes_csv = joinpath(STATS_DIR,"stats","all_holes.csv")
    holes_df = CSV.read(holes_csv, DataFrame, type=String)
    append_all_holes!(holes_df,r)
    CSV.write(holes_csv, holes_df)

    #append round to all_rounds.csv
    rounds_csv = joinpath(STATS_DIR,"stats","all_rounds.csv")
    rounds_df = CSV.read(rounds_csv, DataFrame, type=String)
    append_round!(rounds_df,r)
    CSV.write(rounds_csv, rounds_df)

    #write dash.json with updated data
    dash_json = joinpath(STATS_DIR,"stats","dash.json")
    dash = get_dash_json(throws_df, holes_df, rounds_df)
    open(dash_json, "w") do f
        JSON.print(f, dash, 2)
    end


end



end