extends RefCounted
## Surface detail only: existing building collision/navigation footprints are preserved.
static func populate(w: Node3D) -> void:
	for item in [[-38,-39,10,5,6],[-23,-38,8,4,5],[-44,-19,5,3,11],[-16,19,7,4,11],[16,29,7,4,12],[0,42,17,5,5],[41,-36,12,4,7],[21,-39,5,6,5],[44,-15,5,3,12]]:
		var x=float(item[0]); var z=float(item[1]); var width=float(item[2]); var height=float(item[3]); var depth=float(item[4])
		# Roof parapets, corner posts and concrete plinths break up the box silhouettes.
		for side in [-1,1]:
			w.box(w,Vector3(x,height+.22,z+side*depth/2),Vector3(width+.3,.42,.22),Color("555f55"))
			w.box(w,Vector3(x+side*width/2,height+.22,z),Vector3(.22,.42,depth),Color("555f55"))
			w.box(w,Vector3(x,.21,z+side*(depth/2+.04)),Vector3(width,.4,.12),Color("939078"))
			for xx in [-width*.28,width*.28]:
				for edge in [-1,1]:
					w.box(w,Vector3(x+xx+edge*.66,height/2+.3,z+side*(depth/2+.055)),Vector3(.09,1.16,.1),Color("939078"))
				w.box(w,Vector3(x+xx,height/2-.26,z+side*(depth/2+.12)),Vector3(1.45,.1,.27),Color("939078"))
				w.box(w,Vector3(x+xx,height/2+.3,z+side*(depth/2+.06)),Vector3(.045,1.05,.08),Color("939078"))
				w.box(w,Vector3(x+xx,height/2+.25,z+side*(depth/2+.075)),Vector3(1.25,.045,.08),Color("939078"))
			for xx in [-width/2,width/2]:
				w.box(w,Vector3(x+xx,height/2,z+side*depth/2),Vector3(.24,height,.24),Color("939078"))
			# Rain pipes and door hardware sit flush against existing geometry.
			w.box(w,Vector3(x+width/2-.35,height/2,z+side*(depth/2+.11)),Vector3(.09,height,.09),Color("465346"))
			w.box(w,Vector3(x-.3,1.08,z+side*(depth/2+.09)),Vector3(.1,.045,.08),Color("d1c6a2"))
			w.box(w,Vector3(x-.6,2.22,z+side*(depth/2+.16)),Vector3(1.2,.12,.32),Color("939078"))
	# Road shoulders, paving slabs, drainage and tire marks are opaque geometry.
	for side in [-1,1]:
		for x in range(-68,69,4):
			w.box(w,Vector3(x,-.004,side*5.7),Vector3(3.94,.045,1.1),Color("939078"))
		for x in [-55,-35,-15,15,35,55]:
			w.box(w,Vector3(x,.025,side*5.25),Vector3(1.1,.02,.35),Color("303a33"))
			for k in 5: w.box(w,Vector3(x-.44+k*.22,.04,side*5.25),Vector3(.05,.02,.35),Color("777661"))
		for x in range(-60,61,12):
			w.box(w,Vector3(x,.001,side*1.6),Vector3(8,.012,.12),Color("353c37"))
