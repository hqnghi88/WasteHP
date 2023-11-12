/** 

* Name: NewModel 

* Based on the internal empty template.  

* Author: Tran Thi Mai Hoa 

* Tags:  

*/ 

model NewModel 

global { 

	geometry shape<- envelope(quanlechan3110_shape_file); 

	shape_file quanlechan3110_shape_file <- shape_file("../includes/xe 311-611.shp."); 

	 
	list<point> recyclebin_positions<-[ {2085,1390}, {1900,1200}  ];
	graph road_network; 

	init{ 

		create road from: quanlechan3110_shape_file; 

		road_network <-as_edge_graph(road); 
//		create recyclebin from: recyclebin_positions;
//		create recyclebin number:6{ 
//
//			location <-any_location_in(any(road)); 
//
//		} 
create recyclebin from:csv_file( "../includes/LE-CHAN 2.xlsx - Sheet1.csv",true) with:
			[lat::float(get("lat")), lon::float(get("lon")),  
				address::string(get("address"))
			]{
											location <- to_GAMA_CRS({lon,lat}, "4326").location;
				if (not (location overlaps world.shape)){
					do die;
				}
			}
		 

		create truck number:100{ 

			current_target <-any(recyclebin);		 

			location <-any_location_in(any(road)); 

		} 

		 

	} 

	 

} 

species truck skills:[moving]{ 

	recyclebin current_target; 

	 

	reflex goto{ 

		do goto on: road_network target: current_target; 

		if(location=current_target.location){ 

			current_target <-any(recyclebin); 

		} 

		 

	} 

	 

	aspect default{ 

		draw square(30) color:#green; 

	} 

	 

} 

species road{ 

	aspect default{ 

		draw shape color:#red; 

	} 

} 

species recyclebin{ 
	string address;
	float lat;
	float lon;

	aspect default{ 

		draw triangle(50) color:#blue; 

	} 

} 

experiment main type: gui { 

	output{ 

		display main1 { 
 
			image ("../includes/lechan.png") ;
			species road; 

			species truck; 

			species recyclebin; 

		} 

	} 

} 