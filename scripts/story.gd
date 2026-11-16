extends RefCounted
## Alle Gesprächstexte an einem Ort. Format siehe scripts/game.gd ("Dialoge").
##
## Namen sind Arbeitstitel: "VESPER" steht für Bestgirl aus dem Pitch,
## "DER ZWEITE STUHL" für Fishers Bruder. Hier ändern, dann stimmt es überall.

const MAINY := "DU"
const FISHER := "FISHER"
const VESPER := "VESPER"
const TRADER := "KRÄMER"
const ELDER := "DIE ALTE"
const CSRU := "CSRU  //  ZWEITER STUHL"

const TALKS := {
	# --- Layer II: Auffangbecken ----------------------------------------
	"fisher_meet": {
		"start": {"who": FISHER, "text": "Da bist du ja. Am Stück. Ich hatte gewettet, dass der Arm dich unten auffängt.", "next": "start2"},
		"start2": {"who": FISHER, "text": "Setz dich nicht. Hier setzt man sich nicht. Frag, was du fragen willst.", "next": "hub"},
		"hub": {"who": FISHER, "text": "Na?", "choices": [
			{"text": "Wer bist du wirklich?", "next": "who", "unless": "fisher_who"},
			{"text": "Was ist mit meinem Arm passiert?", "next": "arm", "unless": "fisher_arm"},
			{"text": "Wie komme ich hier raus?", "next": "out", "unless": "fisher_out"},
			{"text": "Wo geht es weiter?", "next": "go"},
		]},
		"who": {"who": FISHER, "set": "fisher_who", "text": "Fisher. Früher CSRU, vierter Stuhl. Dann fand mein Bruder, drei Stühle seien genug.", "next": "who2"},
		"who2": {"who": FISHER, "text": "Seitdem angle ich. Kabel, Leute, Gelegenheiten. Du bist seit Langem der beste Fang.", "next": "hub"},
		"arm": {"who": FISHER, "set": "fisher_arm", "text": "Das Ding, das ganz unten schläft, baut nach, was es berührt. Fleisch aus Kabeln, Kabel aus Fleisch.", "next": "arm2"},
		"arm2": {"who": FISHER, "text": "Die meisten frisst es dabei auf. Dich hat es nur ergänzt. Frag dich mal, warum.", "next": "hub"},
		"out": {"who": FISHER, "set": "fisher_out", "text": "Raus. Der Schacht über dir war der einzige Weg nach oben, und der Pförtner war seine Tür.", "next": "out2"},
		"out2": {"who": FISHER, "text": "Du hast sie von der falschen Seite zugeschlagen. Ab hier geht es nur noch tiefer.", "next": "hub"},
		"go": {"who": FISHER, "text": "Naht. Eine Siedlung. Die haben Wasser, Licht und eine schlechte Meinung von mir.", "next": "go2"},
		"go2": {"who": FISHER, "text": "Folge dem dicken Rohr nach Norden und hak dich an die Portale. Der Boden hört gleich auf.", "next": "go3"},
		"go3": {"who": FISHER, "set": "l2_met_fisher", "event": "l2_to_naht", "text": "Und wenn dort jemand nach mir fragt: Du kennst mich nicht."},
	},
	"fisher_again": {
		"start": {"who": FISHER, "text": "Du stehst ja immer noch hier. Das Rohr entlang, an die Portale. Naht wartet nicht, Naht verfällt."},
	},

	# --- Layer II: Naht -------------------------------------------------
	"vesper_meet": {
		"start": {"who": VESPER, "text": "Stehen bleiben. Der Arm da. Zeig ihn.", "choices": [
			{"text": "(Den Arm zeigen.)", "next": "fresh"},
			{"text": "Nein.", "next": "refuse"},
		]},
		"refuse": {"who": VESPER, "text": "Musst du auch nicht. Man sieht ihn von hier.", "next": "fresh"},
		"fresh": {"who": VESPER, "text": "Frisch. Noch warm. Du bist heute gefallen. Und die Uniform kenne ich: Du bist einer von oben. Einer von denen, die werfen.", "choices": [
			{"text": "War ich.", "next": "honest"},
			{"text": "Ich habe Befehle befolgt.", "next": "orders"},
		]},
		"honest": {"who": VESPER, "set": "vesper_honest", "text": "Wenigstens lügst du nicht.", "next": "name"},
		"orders": {"who": VESPER, "text": "Das sagen die Kabel auch.", "next": "name"},
		"name": {"who": VESPER, "text": "Ich bin Vesper. Wir halten Naht am Leben, solange die CSRU uns lässt.", "next": "hub"},
		"hub": {"who": VESPER, "set": "l2_met_vesper", "text": "Also.", "choices": [
			{"text": "Wer ist die CSRU?", "next": "csru", "unless": "vesper_csru"},
			{"text": "Kennst du einen Fisher?", "next": "fisher", "unless": "vesper_fisher"},
			{"text": "Was willst du von mir?", "next": "want"},
		]},
		"csru": {"who": VESPER, "set": "vesper_csru", "text": "Cybernetic Schizoid Reformation Unit. Vier Leute, die glauben, man könne das Ding da unten wecken und an die Leine legen.", "next": "csru2"},
		"csru2": {"who": VESPER, "text": "Jeder Layer, den sie anfassen, fängt an zu wuchern. Sie nennen das Reformation.", "next": "hub"},
		"fisher": {"who": VESPER, "set": "vesper_fisher", "text": "Wenn du ihn kennst, dann weißt du es schon: Glaub ihm die Richtung, aber nie den Grund.", "next": "hub"},
		"want": {"who": VESPER, "text": "Unser Signalmast ist tot. Draußen, hinter dem Südtor. Seit dort Kriecher nisten, kommt keiner mehr ran.", "next": "want2"},
		"want2": {"who": VESPER, "text": "Du hast einen Haken und nichts zu verlieren. Schalte den Mast ein, dann reden wir darüber, wie es für dich weitergeht.", "choices": [
			{"text": "Ich mache es.", "next": "accept"},
			{"text": "Später.", "next": "later"},
		]},
		"accept": {"who": VESPER, "set": "l2_quest", "event": "l2_quest_start", "text": "Südtor, dann schwingen. Die Kriecher sind schnell, aber sie können nicht fliegen. Du schon."},
		"later": {"who": VESPER, "text": "Der Mast wird nicht heller vom Warten."},
	},
	"vesper_ask": {
		"start": {"who": VESPER, "text": "Der Mast steht immer noch dunkel.", "choices": [
			{"text": "Ich mache es.", "next": "accept"},
			{"text": "Wer ist die CSRU?", "next": "csru", "unless": "vesper_csru"},
			{"text": "Später.", "next": ""},
		]},
		"csru": {"who": VESPER, "set": "vesper_csru", "text": "Vier Leute, die das Ding da unten wecken und an die Leine legen wollen. Jeder Layer, den sie anfassen, fängt an zu wuchern.", "next": "start"},
		"accept": {"who": VESPER, "set": "l2_quest", "event": "l2_quest_start", "text": "Südtor, dann schwingen. Die Kriecher sind schnell, aber sie können nicht fliegen. Du schon."},
	},
	"vesper_waiting": {
		"start": {"who": VESPER, "text": "Südtor, dann schwingen. Das Pult steht am Fuß des Masts."},
	},
	"vesper_done": {
		"start": {"who": VESPER, "xp": 150, "scrap": 40, "text": "Er sendet. Zum ersten Mal, seit wir aufgehört haben, die Tage zu zählen.", "next": "b"},
		"b": {"who": VESPER, "text": "Jetzt hör zu. Die CSRU sucht jemanden wie dich. Einen, den das Inferno angenommen hat, ohne ihn aufzufressen.", "next": "c"},
		"c": {"who": VESPER, "text": "Sie werden kommen. Wenn du mit uns kämpfst, zeige ich dir den Weg nach unten. Dorthin, wo man es beenden kann.", "choices": [
			{"text": "Ich kämpfe.", "next": "fight", "set": "vesper_fight"},
			{"text": "Ich will nur weg.", "next": "leave"},
		]},
		"fight": {"who": VESPER, "text": "Gut. Dann fangen wir damit an, dass —", "next": "cut"},
		"leave": {"who": VESPER, "text": "Weg gibt es hier nicht. Es gibt nur tiefer. Und dafür brauchst du —", "next": "cut"},
		"cut": {"who": "", "set": "l2_finale", "event": "l2_finale", "text": "Alle Lichter in Naht werden rot."},
	},

	"trader": {
		"start": {"who": TRADER, "text": "Schrott gegen Sachen. Kein Kredit, keine Fragen, keine Rückgabe.", "choices": [
			{"text": "Gaskartusche: eine Ladung mehr", "cost": 60, "buy": "gas_tank", "next": "sold"},
			{"text": "Kühlrippen: die Waffe kühlt schneller ab", "cost": 45, "buy": "cooling", "next": "sold"},
			{"text": "Panzerplatte: +25 Integrität", "cost": 50, "buy": "plating", "next": "sold"},
			{"text": "Nichts.", "next": ""},
		]},
		"sold": {"who": TRADER, "text": "Gutes Geschäft. Für mich.", "next": "start"},
		"broke": {"who": TRADER, "text": "Zähl nochmal nach. Ich warte.", "next": "start"},
	},

	"elder": {
		"start": {"who": ELDER, "text": "Unter uns lag ein Königreich. Es hat nach unten gebaut, immer nur nach unten, bis es etwas fand.", "next": "b"},
		"b": {"who": ELDER, "text": "Die letzte Monarchin sitzt noch dort. Sie redet mit dem Ding. Manchmal antwortet es. Durch uns.", "choices": [
			{"text": "Was ist das Ding?", "next": "thing"},
			{"text": "Wie weit ist es bis dorthin?", "next": "far"},
			{"text": "(Gehen.)", "next": ""},
		]},
		"thing": {"who": ELDER, "xp": 30, "text": "Kein Gott. Götter wollen etwas. Das hier träumt nur, und wir sind der Traum, den es gerade hat.", "next": "b"},
		"far": {"who": ELDER, "text": "Layer zählen hilft nicht. Es ist so weit, wie du noch du bist.", "next": "b"},
	},
}

## Funkdurchsage am Ende von Layer II.
const FINALE_LINES := [
	[CSRU, "Naht. Hier spricht der zweite Stuhl."],
	[CSRU, "Bei euch ist etwas vom Himmel gefallen, das uns gehört."],
	[CSRU, "Bruder. Ich weiß, dass du zuhörst. Du hast es zuerst gefunden. Wie immer."],
	[CSRU, "Wir kommen es holen."],
	[VESPER, "Alle auf die Mauern! Du auch, Bulle. Jetzt zeigt sich, was der Arm will."],
]
