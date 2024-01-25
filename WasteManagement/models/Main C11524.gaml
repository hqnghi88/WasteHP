/** 

* Name: NewModel 

* Based on the internal empty template.  

* Author: Tran Thi Mai Hoa 

* Tags:  

*/
model NewModel
global {
	geometry shape <- envelope(quanlechan3110_shape_file);
	shape_file quanlechan3110_shape_file <- shape_file("../includes/mapHp_clean.shp");
	graph road_network;
	list<recyclebin> tocollect <- [];
	recyclebin source;
	map<road, float> road_weights;
	bool block_flood <- false;
	int rushhour_gap <- 100;
	int rushhour_duration <- 400;
	float current_step <- time;
	
	string map_center <- "48.8566140,2.3522219";
		
	init {
		create road from: quanlechan3110_shape_file with: [rname::get("rname"), beta::int(get("beta")), water::int(get("water"))] {
				beta<-1;
				if (block_flood) {
				if (beta = 4) {
				do die;
				}

			}

		}
		write "current step is " + current_step;
		road_network <- as_edge_graph(road);
		road_network <- road_network with_shortest_path_algorithm #Dijkstra;
		create recyclebin from: csv_file("../includes/XERAC.csv", true) with:
		[lat::float(get("lat")), lon::float(get("lon")), manual_cart:: int(get("note")),address::string(get("addresss"))] {
			location <- to_GAMA_CRS({lon, lat}, "EPSG:4326").location;
			volume <- manual_cart * 300;
			if (not (location overlaps world.shape)) {
				do die;
			}

		}
		create thungrac from: csv_file("../includes/thungrac.csv", true) with:
		[lat::float(get("lat")), lon::float(get("lon")),address::string(get("Địa điểm thùng/ điểm tập kết"))]{
			location <- to_GAMA_CRS({lon, lat}, "EPSG:4326").location;
			volume <- 250;
			if (not (location overlaps world.shape)) {
				do die;
			}
		}
			
		
		source <- first(recyclebin where (each.name = "recyclebin0"));
		tocollect <- recyclebin where (each.name != "recyclebin0");
		create truck number: 4 {
			location <- source.location;
			max_capacity <- 12000;
			mySpeed <- 40.0 + rnd(10.0);
			wait_time <- 1;
		}

		create truck number: 3 {
			location <- source.location;
			max_capacity <- 9000;
			mySpeed <- 45.0 + rnd(10.0);
			wait_time <- 1;
		}

		create truck number: 2 {
			location <- source.location;
			max_capacity <- 4000;
			mySpeed <- 40.0 + rnd(10.0);
			wait_time <- 1;
		}
		create truck number: 2 {
			is_backup<-true;
			location <- source.location;
			max_capacity <- 4000;
			mySpeed <- 40.0 + rnd(10.0);
			wait_time <- 1;
		}
		
		create api_loader;
		ask api_loader {
			do run_thread interval: 60 #second;
		}
		
	}

	int cnt <- 0;
	bool jam <- true;

	reflex daytime {
		cnt <- cnt + 1;
		if (jam and cnt > rushhour_duration) {
			jam <- false;
			cnt <- 0;
		}

		if (not jam and cnt > rushhour_gap) {
			jam <- true;
			cnt <- 0;
		}

	}
	
	reflex activate_backup{
		if(flip(0.001)){
			if(length(truck where each.is_backup)>0){
				any(truck where each.is_backup).is_backup<-false;
			}
		}
	}
	
	reflex pausing when: ((tocollect count (each.volume > 0)) = 0) and ((truck count (each.capacity > 0)) = 0) {
		save truck to: "../result/output.csv" format: "csv";
		ask truck {
			save reststop to: "../result/truck" + int(self) + ".csv" format: "csv" header: false;
		}
			
	}

}


species api_loader skills: [thread] {
	float start <- machine_time;
	float end <- machine_time;

	//counting down
	action thread_action {
		try {
			do loadtraffic;
		}

		catch {
			write ".";
		}

	}

	action loadtraffic {
		geometry loc <- (world.shape CRS_transform ("EPSG:4326"));
		map_center <- "" + loc.points[0].y + "," + loc.points[0].x + "," + loc.points[2].y + "," + loc.points[2].x;
		//		write map_center;
		ask traffic_incident {
			do recover;
			do die;
		}

		//				write "https://dev.virtualearth.net/REST/v1/Traffic/Incidents/" + map_center + "?includeJamcidents=true&key=AvZ5t7w-HChgI2LOFoy_UF4cf77ypi2ctGYxCgWOLGFwMGIGrsiDpCDCjliUliln";
		json_file
		sss <- json_file("https://dev.virtualearth.net/REST/v1/Traffic/Incidents/" + map_center + "?includeJamcidents=true&key=AvZ5t7w-HChgI2LOFoy_UF4cf77ypi2ctGYxCgWOLGFwMGIGrsiDpCDCjliUliln");
		map<string, unknown> c <- sss.contents;
		list cells <- c["resourceSets"]["resources"];
		loop mm over: cells {
			loop mmm over: mm as list {
				map<string, unknown> cc <- mmm;
				traffic_incident tt;
				if (cc["point"] != nil) {
					point pp <- cc["point"]["coordinates"];
					geometry pcc <- square(100) at_location (to_GAMA_CRS({pp.y, pp.x}, "4326").location);
					//					write (building  overlapping pcc);
					if (length(road overlapping pcc)>0) {
						create traffic_incident {
							description <- cc["description"];
							tt <- self;
							//					location<-(pp   CRS_transform("EPSG:32648")).location;
							location <- to_GAMA_CRS({pp.y, pp.x}, "4326").location;
							do cause_slowdown;
						}

					}
 
				}

//				if (cc["toPoint"] != nil and tt != nil) {
//					point pp <- cc["toPoint"]["coordinates"];
//					point ppp <- to_GAMA_CRS({pp.y, pp.x}, "4326").location;
//					tt.shape <- line([tt.location, ppp]);
//				}

			}

		}



	}


}

species traffic_incident {
	geometry shape <- circle(30);
	string description;


	action recover{
			list<road> tmp<-road at_distance 1;
			ask tmp{
				incident_beta<-0;
			} 

	}
	action cause_slowdown{
			list<road> tmp<-road at_distance 1;
			ask tmp{
				incident_beta<-4;
			} 

	}

	aspect default {
	//		draw description color: #pink at: location perspective: false font: font("SansSerif", 36, #bold);
		draw triangle(350) color: #red;
	}

}
species truck skills: [moving] {
	recyclebin current_target;
	int max_capacity <- 12000;
	int capacity <- 0;
	int total_cycle <- 0;
	float mySpeed <- 10.0;
	int count_comeback <- 0;
	int count_comeback_notfull <- 0;
	int count_comeback_full <- 0;
	int max_comeback <- 5;
	int max_total_cycle <- 1000;
	float total_distance <- 0.0;
	string reststop <- "";
	int manual_cart;
	bool is_backup<-false;
	
	int wait_time <- 1;
	
	reflex choseTarget when: (current_target = nil) and !is_backup{
		if (capacity < max_capacity) {
			current_target <- (tocollect where (each.collector = nil and each.volume > 0)) closest_to self;
			if (current_target = nil) {
				current_target <- source;
			}

			current_target.collector <- self;
		} else {
			current_target <- source;
		}

	}
	
	geometry old_path <- nil;
	int last_beta <- 1;
	
	reflex goto when: current_target != nil  and !is_backup{
		if (old_path != nil) {
			last_beta <- (jam )? (road(old_path).beta+road(old_path).incident_beta) : 1;
		}

		if wait_time = 0 {

			do goto on: road_network target: current_target speed: mySpeed / (last_beta * last_beta); //recompute_path: true move_weights: road_weights;
			if (old_path != current_edge and current_edge != nil) {
			//			write current_edge;
				total_distance <- total_distance + current_edge.perimeter;
				old_path <- current_edge;
			}

			if (location = current_target.location) {

				if (old_path != nil) {
					reststop <- reststop + ("" + road(old_path).rname + "," + cycle + "\n");
					old_path <- nil;
				}

				if (current_target = source and capacity > 0) {
					count_comeback <- count_comeback + 1;
					if (capacity < max_capacity) {
						count_comeback_notfull <- count_comeback_notfull + 1;
					}

					if (capacity = max_capacity) {
						count_comeback_full <- count_comeback_full + 1;
					}

					capacity <- 0;
					current_target.collector <- nil;
					current_target <- nil;
				} else {
				/*

				 0/12	2	12
				 2/12	6	10
				 8/12	2	4
				10/12	5	2

				 */
					int collected_capacity <- min([current_target.volume, max_capacity - capacity]);
					capacity <- capacity + collected_capacity;
					current_target.volume <- current_target.volume - collected_capacity;
					wait_time <- current_target.manual_cart*100;
					write wait_time;
					current_target.collector <- nil;
					current_target <- nil;
				}
			} else {
				total_cycle <- total_cycle + 1;
			}

		}
		else {
			wait_time <- wait_time -1;
		}
	}
	
	aspect default {
	    float circleRadius <- max_capacity / 100;
	    float textHeight <- 15.0;  // Độ cao của văn bản
		
	    float textX <- location.x - circleRadius / 2;  // Điều chỉnh vị trí X sao cho nằm giữa hình tròn
	    float textY <- location.y + circleRadius / 2 + textHeight / 2;  // Điều chỉnh vị trí Y sao cho nằm trên cùng
		
	    if (location = source.location){
		    draw name at: {textX, textY} color: #purple font: font("Arial", 15, #bold
		    ) perspective: true;
		}
		if (wait_time > 0) {
			draw name at: {textX, textY} color: #red font: font("Arial", 15, #bold
		    ) perspective: true;
		}
		else{
			draw name at: {textX, textY} color: #green font: font("Arial", 15, #bold
		    ) perspective: true;
		
		}
		draw circle(circleRadius) color: is_backup?#darkgray:#green;
     // draw "" + int(capacity / max_capacity * 100) + "%" color: #red font: font("Arial", 18, #bold) perspective: true;
	 //	draw "" + count_comeback + "" color: #red font: font("Arial", 18, #bold) perspective: true;
		
	}
}

species road {
	int beta <- 1;
	int incident_beta<-0;
	int water <- 1;
	string rname;

	//aspect default {
	//		if (  water > 1) {
	//			draw shape + (beta * 5) color: water > 1 ? #indigo : #grey;
	//		}
	//	if (jam) {
	//		draw shape + (beta < 99 ? beta * 5 : 5) color: beta > 1 ? #cyan : #black;
	//	} else {
	//		draw shape + 5 color: #black;
	//	}

	//}

}

species recyclebin {
	truck collector;
	string address;
	float lat;
	float lon;
	int manual_cart;
	int volume <- 0;

	reflex pollute {
	}

	aspect default {
		if (self = source) {
			draw square(200) color: #purple;
		}

		if (volume > 0) {
		//				draw triangle(150) color: #blue;
				//	draw "" + volume color: #yellow font: font("Arial", 15, #bold);
			draw square(150) color: #red;
		}

	}

}

species thungrac{
	truck collector;
	string address;
	float lat;
	float lon;
	int manual_cart;
	int volume <- 0;

	reflex pollute {
	}
	
	aspect default {
		if (volume > 0) {
		//				draw triangle(150) color: #blue;
				//	draw "" + volume color: #yellow font: font("Arial", 15, #bold);
			draw square(150) color: #blue;
		}
	}
}

experiment main type: gui {
	float minimum_cycle_duration <- 0.001;
	output synchronized: false {
		layout horizontal([0::6190, 1::3810]) parameters: false navigator: false editors: false consoles: false toolbars: false tray: false tabs: false controls: true;
		//		layout parameters: false navigator: false editors: false consoles: false toolbars: false tray: false tabs: false controls: true;
		display main1 type: 3d axes: false background: #black {
		//			camera 'default' location: {7173.9067, 4452.2435, 8396.4835} target: {7173.9067, 4452.0969, 0.0};
			image ("../includes/background2.png") position: 	{0, 0, -0.0001};
			species road;
			species traffic_incident ;
			species truck;
			species recyclebin position: {0, 0, 0.000001};
			species thungrac position: {0, 0, 0.0001};
		}

		display main2 type: 3d axes: false background: #black {
			graphics stats { 
				int y <- 0;
				loop o over: truck {
					draw "" + o + " came back " + o.count_comeback + " times, not full " + o.count_comeback_notfull + " times" at: {500, y} color: #white font: font("Arial", 15, #bold);
					y <- y + 500;
					draw "Distances:" + int(o.total_distance / 1000) + " km" + ", duration: " + o.total_cycle + " cycles" at: {1000, y} color: #white font: font("Arial", 15, #bold);
					y <- y + 500;
				}

			}

		}

	}

} 