/** 

* Name: NewModel 

* Based on the internal empty template.  

* Author: Tran Thi Mai Hoa 

* Tags:  

*/
model NewModel

global {
	geometry shape <- envelope(quanlechan3110_shape_file);
	shape_file quanlechan3110_shape_file <- shape_file("../includes/quanlechan.shp");
	graph road_network;
	list<recyclebin> tocollect <- [];
	recyclebin source;

	init {
		create road from: quanlechan3110_shape_file;
		road_network <- as_edge_graph(road);
		create recyclebin from: csv_file("../includes/LE-CHAN 2.xlsx - Sheet1.csv", true) with:
		[lat::float(get("lat")), lon::float(get("lon")), max_volume::int(get("note")), address::string(get("address"))] {
			location <- to_GAMA_CRS({lon, lat}, "4326").location;
			volume <- max_volume;
			if (not (location overlaps world.shape)) {
				do die;
			}

		}

		source <- first(recyclebin where (each.name = "recyclebin130"));
		tocollect <- recyclebin where (each.name != "recyclebin130");
		create truck number: 6 {
			location <- source.location;
		}

	}

	reflex pausing when: ((tocollect count (each.volume > 0)) = 0) and((truck count(each.capacity>0))=0){
		do pause;
	}

}

species truck skills: [moving] {
	recyclebin current_target;
	int max_capacity <- 12;
	int capacity <- 0;

	reflex choseTarget when: current_target = nil {
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

	reflex goto when: current_target != nil {
		do goto on: road_network target: current_target speed: 10.0;
		if (location = current_target.location) {
			if (current_target = source) {
				capacity <- 0;
				current_target.collector <- nil;
				current_target <- nil;
			} else {
				capacity <- current_target.volume;
				current_target.volume <- 0;
				current_target.collector <- nil;
				current_target <- nil;
			}

		}

	}

	aspect default {
		draw square(30) color: #green;
		draw "" + int(capacity / max_capacity * 100) + "%" color: #red font: font("Arial", 18, #bold) perspective: true;
	}

}

species road {

	aspect default {
		draw shape + 5 color: #red;
	}

}

species recyclebin {
	truck collector;
	string address;
	float lat;
	float lon;
	int max_volume;
	int volume <- 0;

	reflex pollute {
	}

	aspect default {
		if (volume > 0) {
		//		draw triangle(50) color: #blue;
			draw "" + volume color: #blue font: font("Arial", 25, #bold);
		}

	}

}

experiment main type: gui {
	output synchronized:true{
		display main1 type: 3d {
			image ("../includes/lechan.png") position: {0, 0, -0.0001};
			//			species road;
			species truck;
			species recyclebin position: {0, 0, 0.0000001};
		}

	}

} 