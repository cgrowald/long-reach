extends RefCounted
## The command hack on the depot's vault control PC (docs/DEPOT_SLICE.md section 8). Gamified, never real
## procedure. You tell your stick carrier what to type; the time is them typing it, letter by letter (faster
## with more tech), and while they type they're out of the fight: covering the door is your job.
##   scan            find what the doors are cabled to
##   link door_ctl   connect to the door controller (it wants a 4-digit service PIN)
##   sniff           listen on the wire for a while: one PIN digit
##   brute           try them all: slow, a few seconds of tries per unknown digit
##   login <pin>     three wrong PINs lock the system out
##   manifest        read what's logged behind each door (intel)
## A better stick does some work itself (1 star: scans on plug-in; 2: one digit; 3: brute twice as fast).
## Logged in, the system grants ONE door.

const RUN_S := {"scan": 1.5, "link": 1.0, "sniff": 5.0, "login": 0.8, "manifest": 2.5, "help": 0.0}
const BRUTE_PER_DIGIT := 4.0
const TRIES := 3

var lines: Array = []            # [text, kind] kind: cmd, out, ok, bad, hint
var pin := ""
var known: Array = [false, false, false, false]
var scanned := false
var linked := false
var logged_in := false
var locked_out := false
var tries_left := TRIES
var running := {}                # {cmd, arg, text, typed (chars), t, dur}
var tech := 1
var stars := 0
var rng := RandomNumberGenerator.new()
var on_manifest: Callable        # reveals the door hints (set by the op)
var who := "Your carrier"
var host := "vaultctl"


func start(seed_: int, p_tech: int, p_stars: int, carrier_name: String) -> void:
	rng.seed = seed_
	tech = clampi(p_tech, 0, 5)
	stars = maxi(0, p_stars)
	who = carrier_name
	pin = ""
	for i in 4:
		pin += str(rng.randi_range(0, 9))
	lines.append(["VAULTCTL maintenance shell. Type 'help'.", "out"])
	if stars >= 1:
		scanned = true
		lines.append(["[stick] auto-scan: door_ctl (3 doors, cabled)", "ok"])
	if stars >= 2:
		_reveal_one()
		lines.append(["[stick] caught a digit: PIN %s" % pin_shown(), "ok"])


## Letters a second they type: tech 0 = 2.5, tech 5 = 8.5.
func cps() -> float:
	return 2.5 + tech * 1.2


func pin_shown() -> String:
	var s := ""
	for i in 4:
		s += pin[i] if known[i] else "_"
	return s


func prompt() -> String:
	return "%s@%s:~$ " % [who.to_lower(), host]


## Short words for what makes sense next (clickable in the terminal's bottom line).
func suggestions() -> Array:
	if locked_out or logged_in:
		return []
	if not scanned:
		return ["scan", "help"]
	if not linked:
		return ["link door_ctl", "manifest"]
	var out: Array = []
	if known.count(false) > 0:
		out.append("sniff")
		out.append("brute")
		out.append("login ")
	else:
		out.append("login " + pin)
	out.append("manifest")
	return out


func busy() -> bool:
	return not running.is_empty()


## What they're typing right now (for the shell line).
func typing_text() -> String:
	if running.is_empty():
		return ""
	return str(running["text"]).substr(0, int(running["typed"]))


func typing_done() -> bool:
	return not running.is_empty() and int(running["typed"]) >= str(running["text"]).length()


## Tell them a command. Returns "" or why not (bad commands still get typed, then fail: that's the cost).
func submit(text: String) -> String:
	if busy():
		return "%s is still typing." % who
	if locked_out or logged_in:
		return ""
	var t := text.strip_edges().to_lower()
	if t == "":
		return ""
	var parts := t.split(" ", false)
	var cmd: String = parts[0]
	var arg: String = parts[1] if parts.size() > 1 else ""
	var dur := float(RUN_S.get(cmd, 0.3))
	if cmd == "brute":
		dur = known.count(false) * BRUTE_PER_DIGIT * (0.5 if stars >= 3 else 1.0)
	running = {"cmd": cmd, "arg": arg, "text": t, "typed": 0.0, "t": 0.0, "dur": dur}
	return ""


## Real seconds pass while they type and the command runs. Returns true when a command just finished.
func tick(delta: float) -> bool:
	if running.is_empty():
		return false
	var text: String = running["text"]
	if float(running["typed"]) < text.length():
		running["typed"] = minf(text.length(), float(running["typed"]) + delta * cps())
		return false
	running["t"] = float(running["t"]) + delta
	if float(running["t"]) < float(running["dur"]):
		return false
	var cmd: String = running["cmd"]
	var arg: String = running["arg"]
	lines.append([prompt() + text, "cmd"])
	running = {}
	_run(cmd, arg)
	return true


func _run(cmd: String, arg: String) -> void:
	match cmd:
		"help":
			lines.append(["scan, link <device>, sniff, brute, login <pin>, manifest", "hint"])
		"scan":
			scanned = true
			lines.append(["door_ctl (3 doors, cabled)   cam_srv   print_q", "ok"])
		"link":
			if not scanned:
				lines.append(["link: no devices known. scan first.", "bad"])
			elif arg != "door_ctl":
				lines.append(["link: no device '%s'" % arg, "bad"])
			else:
				linked = true
				lines.append(["linked: door_ctl. service PIN required (4 digits).", "ok"])
		"sniff", "brute", "manifest", "login":
			if not linked:
				lines.append(["%s: not linked to door_ctl" % cmd, "bad"])
				return
			match cmd:
				"sniff":
					if known.count(false) == 0:
						lines.append(["sniff: nothing new. PIN %s" % pin, "out"])
					else:
						_reveal_one()
						lines.append(["caught a service login: PIN %s" % pin_shown(), "ok"])
				"brute":
					for i in 4:
						known[i] = true
					lines.append(["brute: match. PIN %s" % pin, "ok"])
				"manifest":
					if on_manifest.is_valid():
						on_manifest.call()
					lines.append(["manifest: door contents logged (see the doors)", "ok"])
				"login":
					if arg == pin:
						logged_in = true
						lines.append(["ACCESS GRANTED. maintenance: ONE door, then lockout.", "ok"])
					else:
						tries_left -= 1
						if tries_left <= 0:
							locked_out = true
							lines.append(["login failed. SYSTEM LOCKOUT.", "bad"])
						else:
							lines.append(["login failed. %d tr%s left." % [tries_left, "y" if tries_left == 1 else "ies"], "bad"])
		_:
			lines.append(["%s: command not found" % cmd, "bad"])


func _reveal_one() -> int:
	var hidden: Array = []
	for i in 4:
		if not known[i]:
			hidden.append(i)
	if hidden.is_empty():
		return 0
	var i: int = hidden[rng.randi() % hidden.size()]
	known[i] = true
	return i
