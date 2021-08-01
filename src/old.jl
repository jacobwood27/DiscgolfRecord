

function preview_course(c::Course)
    kml = course_kml(c)
    filename = id(c) * "_preview.kml"
    open(filename,"w") do f
        for line in kml
            println(f, line)
        end
    end
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

function illustrate(r::Round; out="test_vis.kml")
    
    #write the .kml file
    xdoc = XMLDocument()

    xroot = create_root(xdoc, "kml")
    set_attribute(xroot, "xmlns", "http://www.opengis.net/kml/2.2")

    xc = new_child(xroot, "Folder")
    set_attribute(xc, "id", "Visualization")

    # Define some icon styles we will be using
    styles = [  
        ("tee_style", "http://maps.google.com/mapfiles/kml/paddle/grn-blank.png", "1", "1"),
        ("pin_style", "http://maps.google.com/mapfiles/kml/paddle/blu-blank.png", "1", "1")
        ]
    for r in eachrow(DISCS_DB)
        s = (r.my_id, r.image, "1.5", "0")
        push!(styles, s)
    end
    for s in styles
        s1 = new_child(xc, "Style")
        set_attribute(s1, "id", s[1])
        s1_1 = new_child(s1, "IconStyle")
        temp_lss = new_child(s1_1, "scale")
        add_text(temp_lss, s[3])
        s1_2 = new_child(s1_1, "Icon")
        s1_3 = new_child(s1_2, "href")
        add_text(s1_3, s[2])
        temp_ls = new_child(s1, "LabelStyle")
        temp_lss = new_child(temp_ls, "scale")
        add_text(temp_lss, s[4])
    end

    # Define some line styles we will be using
    styles = [  
        ("under_style", "FF00FF14", "3"),
        ("par_style", "FFFF7800", "3"),
        ("over_style", "FF1400FF", "3")
        ]
    for s in styles
        s1 = new_child(xc, "Style")
        set_attribute(s1, "id", s[1])
        s1_1 = new_child(s1, "LineStyle")
        s1_2 = new_child(s1_1, "color")
        add_text(s1_2, s[2])
        s1_3 = new_child(s1_1, "width")
        add_text(s1_3, s[3])
    end


    # create the first child, a plot of the course
    c = course(r)

    xc1 = new_child(xc, "Document")
    temp_n = new_child(xc1, "name")
    add_text(temp_n, "Course")

    # And add all the holes as children beneath that doc
    for h in holes(c)
        temp = new_child(xc1,"Document")
        temp_n = new_child(temp, "name")
        add_text(temp_n, id(h))

        for t in tees(h)
            temp_p = new_child(temp, "Placemark")
            temp_n = new_child(temp_p, "name")
            add_text(temp_n, id(h) * id(t))
            temp_s = new_child(temp_p, "styleUrl")
            add_text(temp_s, "#tee_style")
            temp_pnt = new_child(temp_p, "Point")
            temp_c = new_child(temp_pnt, "coordinates")
            add_text(temp_c, "$(lon(t)),$(lat(t)),0")
        end

        for p in pins(h)
            temp_p = new_child(temp, "Placemark")
            temp_n = new_child(temp_p, "name")
            add_text(temp_n, id(h) * id(p))
            temp_s = new_child(temp_p, "styleUrl")
            add_text(temp_s, "#pin_style")
            temp_pnt = new_child(temp_p, "Point")
            temp_c = new_child(temp_pnt, "coordinates")
            add_text(temp_c, "$(lon(p)),$(lat(p)),0")
        end

        for t in tees(h), p in pins(h)
            temp_p = new_child(temp, "Placemark")
            temp_n = new_child(temp_p, "name")
            add_text(temp_n, "$(id(h)), $(id(t)) -> $(id(p))")
            temp_ls = new_child(temp_p, "LineString")
            temp_c = new_child(temp_ls, "coordinates")
            add_text(temp_c, "$(lon(p)),$(lat(p))\n$(lon(t)),$(lat(t))")
        end




    end

    xc2 = new_child(xc, "Document")
    temp_n = new_child(xc2, "name")
    add_text(temp_n, "Round")

    for h in holes(r)
        temp = new_child(xc2,"Document")
        temp_n = new_child(temp, "name")
        add_text(temp_n, id(h.hole))
        
        for (i,t) in enumerate(h.throws)
            temp_p = new_child(temp, "Placemark")
            temp_n = new_child(temp_p, "name")
            add_text(temp_n, "Throw $i")
            temp_s = new_child(temp_p, "styleUrl")
            if h.res < 0
                add_text(temp_s, "#under_style")
            elseif h.res == 0
                add_text(temp_s, "#par_style")
            else
                add_text(temp_s, "#over_style")
            end
            temp_ls = new_child(temp_p, "LineString")
            temp_c = new_child(temp_ls, "coordinates")
            add_text(temp_c, "$(lon(t.loc1)),$(lat(t.loc1))\n$(lon(t.loc2)),$(lat(t.loc2))")
        end

        for (i,t) in enumerate(h.throws)
            temp_p = new_child(temp, "Placemark")
            temp_n = new_child(temp_p, "name")
            add_text(temp_n, "Throw $i")
            temp_s = new_child(temp_p, "styleUrl")
            add_text(temp_s, "#$(t.disc)")
            temp_ls = new_child(temp_p, "Point")
            temp_c = new_child(temp_ls, "coordinates")
            add_text(temp_c, "$(lon(t.loc1)),$(lat(t.loc1)),0")
        end
    end

    save_file(xdoc, out)
end
