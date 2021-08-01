#!/usr/bin/env julia

using JSON, CSV, DataFrames, DataStructures, ArgParse

function make_course_json(tees_file, pins_file, id, name)

    println("Note: par is initialized to 3 for all hole combinations. Edit resulting json manually.")

    holes_dict = OrderedDict()

    tees_df = CSV.read(tees_file, DataFrame)
    pins_df = CSV.read(pins_file, DataFrame)

    hole_names = unique(tees_df.hole)

    

    for h in hole_names
        hole_dict = OrderedDict()
        
        td = OrderedDict()
        for r in eachrow(tees_df)
            if r.hole == h
                ismissing(r.variation) ? key = "" : key = r.variation 
                td[key] = [r.lat, r.lon]
            end
        end
        hole_dict[:tees] = td

        pd = OrderedDict()
        for r in eachrow(pins_df)
            if r.hole == h
                ismissing(r.variation) ? key = "" : key = r.variation
                pd[key] = [r.lat, r.lon]
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
    D[:id] = id
    D[:name] = name
    D[:loc] = [tees_df.lat[1], tees_df.lon[1]]
    D[:holes] = holes_dict

    open("$id.json", "w") do f
        JSON.print(f, D, 2)
    end

end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "tees"
            help = "Tees file"
            required = true
        "pins"
            help = "Pins file"
            required = true
        "id"
            help = "Course ID"
            required = true
        "name"
            help = "Course Name"
            required = true
        
    end
    return parse_args(s)
end

args = parse_commandline()

make_course_json(args["tees"], args["pins"], args["id"], args["name"])