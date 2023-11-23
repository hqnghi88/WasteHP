/** 

* Name: NewModel 

* Based on the internal empty template.  

* Author: Tran Thi Mai Hoa 

* Tags:  

*/
model NewModel

global {
	geometry shape <- envelope(quanlechan3110_shape_file);
	shape_file quanlechan3110_shape_file <- shape_file("../includes/mapTP_clean.shp");
	graph road_network;
	list<recyclebin> tocollect <- [];
	recyclebin source; 
	init {
		create road from: quanlechan3110_shape_file;
		road_network <- as_edge_graph(road);
		road_network <- road_network with_shortest_path_algorithm #AStar;
		create recyclebin from: csv_file("../includes/LE-CHAN 2.xlsx - Sheet1.csv", true) with:
		[lat::float(get("lat")), lon::float(get("lon")), manual_cart::int(get("note")), address::string(get("addresss"))] {
			location <- to_GAMA_CRS({lon, lat}, "4326").location;
			volume <- manual_cart * 300;
			if (not (location overlaps world.shape)) {
				do die;
			}

		}

		source <- first(recyclebin where (each.name = "recyclebin0"));
		tocollect <- recyclebin where (each.name != "recyclebin0");
		create truck number: 3 {
			location <- source.location;
			max_capacity <- 12000;
			mySpeed <- 40.0 + rnd(10.0);
		}

		create truck number: 2 {
			location <- source.location;
			max_capacity <- 9000;
			mySpeed <- 45.0 + rnd(10.0);
		}

		create truck number: 1 {
			location <- source.location;
			max_capacity <- 4000;
			mySpeed <- 45.0 + rnd(10.0);
		}

	}

	reflex pausing when: ((tocollect count (each.volume > 0)) = 0) and ((truck count (each.capacity > 0)) = 0) {
		save truck to: "../result/output.csv" format: "csv";
		do pause;
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
	int total_distance <- 0;

	reflex choseTarget when: (current_target = nil) {
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

	reflex goto when: current_target != nil {
		do goto on: road_network target: current_target speed: mySpeed;
		if (old_path != current_edge and current_edge != nil) {
//			write current_edge;
			total_distance <- total_distance+ current_edge.perimeter;
			old_path <- current_edge;
		}

		if (location = current_target.location) {
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
				current_target.collector <- nil;
				current_target <- nil;
			}

		}else{
		total_cycle <- total_cycle + 1;}

	}

	aspect default {
		draw square(130) color: #green;
		draw "" + int(capacity / max_capacity * 100) + "%" color: #red font: font("Arial", 18, #bold) perspective: true;

		//		draw "" + count_comeback + "" color: #red font: font("Arial", 18, #bold) perspective: true;
	}

}

species road {

	aspect default {
		draw shape + 5 color: #grey;
	}

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
		if (volume > 0) {
		//				draw triangle(150) color: #blue;
			draw "" + volume color: #yellow font: font("Arial", 15, #bold);
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
			image ("../includes/HP.png") position: {0, 0, -0.0001};
			species road;
			species truck;
			species recyclebin position: {0, 0, 0.000001};
		}

		display main2 type: 3d axes: false background: #black {
			graphics stats {
				int y <- 0;
				loop o over: truck {
					draw "" + o + " came back " + o.count_comeback + " times, not full " + o.count_comeback_notfull + " times" at: {500, y} color:#white font: font("Arial", 15, #bold);
					y <- y + 500;
					draw "Distances:" + int(o.total_distance/1000) + " km"+", duration: "+o.total_cycle+" cycles" at: {1000, y} color:#white  font: font("Arial", 15, #bold);
					y <- y + 500;
				}

			}

		}

	}

} 