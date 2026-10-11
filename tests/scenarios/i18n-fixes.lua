-- The translated clients, round 34's i18n hunt:
--
-- 1. The "In character" box a player saved in their own language stopped
--    being recognised when a later release reworded the translation of an
--    example line (1.6.6's "Translations read for fluency" did, in all eight
--    languages), so the set went silent for everybody who updated over it and
--    their saved lines were said at random instead. RP.LEGACY_TRANSLATED keeps
--    what such a line read before, per language, and RP.Active reads those
--    lines as they read now. The boxes below are taken from release tags
--    (python tools/audit_saved_boxes.py --tags v1.6.5 lists every one).
-- 2. A whisper thank-you was dropped for anybody whose surname is not plain
--    A to Z: WhisperTargetOf walked the line with the word pattern Forever's
--    chat box had until 1.60.1 (70205), %w+, which no accent, apostrophe,
--    Hangul or Chinese character matches. The box reads "[%s-](%S+)%s" now
--    (Gethe/wow-ui-source, branch forever, Blizzard_ChatFrameBase/Shared/
--    ChatFrameEditBox.lua).
-- 3. The end of a snooze was written with an English AM or PM; the client
--    writes its own 12-hour clock from TIME_TWELVEHOURAM and
--    TIME_TWELVEHOURPM ("오전 %d:%02d", "%d:%02d a.m.", "%d:%02d du matin").
--
-- Every scenario name starts with "i18n-fix:" so the mutations in
-- tests/mutations/i18n-fixes.py can name the one that has to catch them.
--
-- Called by scenarios.lua with the addon directory and its helpers.

local dir, H = ...
local fail, load, drive = H.fail, H.load, H.drive

-- Messages name text by its bytes: the console these run in on Windows
-- cannot print an accent, let alone Hangul, and the runner throws on one.
local function ascii(text)
	return (tostring(text):gsub("[\128-\255]", function(c) return ("\\%d"):format(c:byte()) end))
end

-- ------------------------------------------------------------------ i18n-fix 1
-- What a mage of that people and side had in the box after a release, in the
-- language it was filled in.
local SAVED = {
	{ tag = "1.6.5", code = "deDE", race = "Draenei", faction = "Alliance", box = [==[Das Licht belohnt Güte, {name}. Ich bin nur sein schnellster Bote.
Archenon poros, {name}. Eure Gabe sei erwidert.
Danke, {name}. Mitfliegen in der Exodar? Ihr habt gesehen, wie sie landet.
Freimütig gegeben, {name}. Die Naaru summen etwas lauter. Erwidert.
Gewiss, {name}. Die Naaru leiten Eure Schritte; das hier beschwingt sie.
Gern, {name}. Das Licht antwortet denen, die bitten.
Velen sah Eure Bitte voraus, {name}. Ich sah mein Ja voraus.
Das Licht ist mit Euch, {name}. Geht in Frieden, oder zumindest gerüstet.
Wandelt im Licht, {name}. Möge es Euch stets behüten.
Nehmt das, {name}. Unser Gepäck ist leicht. Und Licht.
Nehmt das, {name}. Die Legion kommt immer. Ich muss es wissen.
Für die Allianz, {name}! Bleibt stark. Ab jetzt noch stärker.
Vorwärts, {name}. Die Allianz ist mit Euch.
Bleibt nah, {name}. Ich verlor schon eine Welt; diese Gruppe halte ich fest.
Fünfundzwanzigtausend Jahre auf der Flucht, {name}. Mit Freunden geht's schöner.
Die Naaru nennen das Gemeinschaft, {name}. Ich nenne es Glück.
Gemeinsam stehen wir, {name}. Für die Allianz!
Also, {name}: Schilde hoch, Köpfe runter, und keiner stürmt vor dem Plan los.
Archenon poros, {name}! Die Kinder von Argus stehen einander bei.
Hier, {name}. Ein Gedanke war übrig, und wohin damit?
Nehmt dies, {name}. Ohne Brot; gezaubertes schmeckt nach nichts.
Wir müssen aufhören, uns so zu treffen, {name}. Nein, eigentlich nicht.
Irgendwo hier probt ein Schurke seine Rede, {name}. Unterbrechen wir ihn.]==] },
	{ tag = "1.6.5", code = "esES", race = "Dwarf", faction = "Alliance", box = [==[¡Gracias de corazón, {name}! La primera ronda la pago yo en la forja.
Te debo una, {name}. Ya tienes amigos en la montaña.
¡Gracias, {name}! Me las habría arreglado sin esto, ojo. Pero gracias.
¡Bendiciones, {name}! Te abrazaría, pero luego te haría falta un sanador.
¡Claro, {name}, bastaba con pedirlo! Firme como un buen yunque.
Ni una palabra más, {name}. Piedra y acero, ¡ahí va!
Pídele ayuda a un enano, {name}, y la tendrás. A gritos.
Toma, {name}, un detallito pa' que no flaquees. Chiquito, como yo.
Andando, {name}, firme como la montaña.
Toma, {name}. La cerveza, pa' después; esto, pa' antes.
Magni fundiría su corona por un amigo, {name}. Esto sale más barato.
¡Por la Alianza, {name}! Mantente fuerte ahí fuera. Ahora, más aún.
Adelante, {name}. La Alianza está contigo.
Ponte detrás de mí, {name}. Ya, ya lo sé. Agáchate un poco.
Bien, {name}: yo voy delante, tú te llevas el botín y luego discutimos.
Si empiezo a cantar, {name}, es que el combate fue bien. O muy mal.
Unidos resistimos, {name}. ¡Por la Alianza!
Bien, {name}: escudos arriba, cabeza agachada y nadie carga antes que el plan.
¡Piedra y martillo te guarden, pariente {name}!
Toma, {name}. Me sobraba una idea y no sabía dónde ponerla.
Toma, {name}. Añadiría pan, pero el pan conjurado no sabe a nada.
Tenemos que dejar de vernos así, {name}. Bueno, no, qué va.
Aquí dentro un villano ensaya su discurso, {name}. Vamos a interrumpirlo.
¡Buenos días, {name}! Temprano pa' la cerveza. Casi. Toma esto antes.]==] },
	{ tag = "1.6.5", code = "frFR", race = "Dwarf", faction = "Alliance", box = [==[Merci bien, {name} ! La première tournée est pour moi, de retour à la forge.
Mille mercis, {name}. Z'avez un ami dans la montagne, maint'nant.
Merci, {name} ! J'aurais tenu sans, remarquez. Mais merci.
Merci, {name} ! Une accolade ? Non, z'auriez besoin d'un soigneur après.
Pour sûr, {name}, suffisait d'demander. Bougez plus, comme une bonne enclume.
Pas un mot d'plus, {name}. Par la pierre et l'acier, ça vient !
Demandez d'l'aide à un nain, {name} : vous l'aurez. Et vous l'entendrez.
Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb. P'tit, comme moi.
En route, {name}, et solide comme la montagne.
Tenez, {name}. La bière, c'est pour après ; ça, c'est pour avant.
Magni fondrait sa couronne pour un ami, {name}. Ça, c'est l'option pas chère.
Pour l'Alliance, {name} ! Restez fort là-dehors. Plus fort, désormais.
En avant, {name}. L'Alliance est avec vous.
Derrière moi, {name}. Oui, j'sais. Baissez-vous un peu.
Bon, {name} : j'prends l'avant, vous prenez l'butin, et on s'dispute après.
Si j'me mets à chanter, {name}, c'est qu'le combat s'passe bien. Ou très mal.
Unis, nous tiendrons, {name}. Pour l'Alliance !
Bien, {name} : boucliers levés, têtes baissées, et personne ne charge avant le plan.
Pierre et marteau vous gardent, cousin {name} !
Tenez, {name}. J'avais une pensée en trop et nulle part où la ranger.
Prenez ceci, {name}. J'ajouterais du pain, mais le pain invoqué n'a aucun goût.
Il faut qu'on arrête de se croiser comme ça, {name}. En fait, non, pas du tout.
Quelque part ici, un méchant répète son discours, {name}. Interrompons-le.
B'jour, {name} ! Trop tôt pour une bière. Presque. Prenez d'abord ça.]==] },
	{ tag = "1.6.5", code = "itIT", race = "Dwarf", faction = "Alliance", box = [==[Grazie di cuore, {name}! Alla forgia il primo giro lo offro io.
Grazie assai, {name}. Ora hai un amico nella montagna.
Grazie, {name}! Me la sarei cavata anche senza, sia chiaro. Ma grazie.
Evviva, {name}! Ti abbraccerei, ma poi ti servirebbe un guaritore.
Ma certo, {name}, bastava chiedere! Ora immobile, come una brava incudine.
Non dire altro, {name}. Pietra e acciaio, eccolo che arriva!
Chiedi aiuto a un nano, {name}, e l'avrai. A pieni polmoni.
Tieni, {name}, un aiutino per tenerti in piedi. Piccolo, come me.
Va' pure, {name}, con passo saldo come la montagna.
Tieni, {name}. La birra è per dopo; questo è per prima.
Magni fonderebbe la sua corona per un amico, {name}. Questa è la versione economica.
Per l'Alleanza, {name}! Resta forte là fuori. Anzi, ora più forte.
Avanti, {name}. L'Alleanza è con te.
Mettiti dietro di me, {name}. Sì, lo so. Abbassati un po'.
Allora, {name}: io sto davanti, tu prendi il bottino, e poi litighiamo.
Se comincio a cantare, {name}, va alla grande. O malissimo.
Uniti siamo forti, {name}. Per l'Alleanza!
Allora, {name}: scudi alti, testa bassa, e nessuno carica prima del piano.
Pietra e martello ti proteggano, {name}! Siamo della stessa roccia.
Tieni, {name}. Mi avanzava un pensiero, e non sapevo dove metterlo.
Prendi, {name}. Ci aggiungerei il pane, ma quello evocato non sa di niente.
Dobbiamo smetterla di vederci così, {name}. Anzi, no.
Qui dentro un cattivo sta provando il suo discorso, {name}. Interrompiamolo.
'Giorno, {name}! Troppo presto per la birra. Quasi. Prima questo.]==] },
	{ tag = "1.6.5", code = "koKR", race = "NightElf", faction = "Alliance", box = [==[Ishnu-alah, {name}. 당일에 갚다니, 칼도레이로선 서두른 셈이오.
감사하오, {name}. 엘룬께선 베푸는 이에게 미소 지으신다오.
감사하오, {name}. 좀처럼 감동 않는 위습들마저 더 밝게 빛나는구려.
엘룬께서 보셨소, {name}. 다 보시는 분이니, 얼른 갚아야겠소.
기꺼이, {name}. 가만히, 달빛이 그대에게 닿도록.
물론이지요, {name}. 엘룬의 축복은 나누라고 있는 것이니.
드디어, {name}! 누가 청해 주길 만 년이나 기다렸소.
Elune-adore, {name}. 사뿐히 걸으시오. 나무들은 잠귀가 밝으니.
{name}, 어디를 가든 숲이 그대를 품어 주기를.
그림자 속에서 주는 선물이오, {name}. 아니, 찾지 마시오. 못 찾을 테니.
엘룬께서 그대의 길을 비추시오, {name}. 난 등불만 들었을 뿐.
얼라이언스를 위하여, {name}! 굳건히 버티시오. 이제 더 굳건히.
전진하시오, {name}. 얼라이언스가 함께하오.
금방 끝내자고, {name}? 칼도레이 셈법으론 시작 전에 끝난 셈이오.
난 안 보이는 쪽을 맡으리다, {name}. 실수가 아니라 작전이오.
엘룬께서 파티 전체를 지켜보시오, {name}. 난 손 흔드는 담당이고.
뭉쳐야 사는 법이오, {name}. 얼라이언스를 위하여!
자, {name}. 방패는 들고, 고개는 숙이고, 작전보다 먼저 돌격하는 자 없기요.
Ishnu-alah, {name}. 엘룬께선 자녀들을 늘 곁에 두시지요.
여기, {name}. 생각이 하나 남는데 둘 데가 없어서.
받으시오, {name}. 빵도 얹고 싶지만, 마법으로 만든 빵은 아무 맛이 안 나오.
이렇게 자꾸 만나면 곤란하오, {name}. 아니, 곤란할 거 없구려.
이 안 어딘가서 악당이 연설 연습 중이오, {name}. 가서 끊어 줍시다.
달이 떴소, {name}. 칼도레이에겐 지금이 한창 아침이오.
아침이구려, {name}. 우린 수천 년간 아침엔 잤소. 적응 중이오.]==] },
	{ tag = "1.6.5", code = "ptBR", race = "Dwarf", faction = "Alliance", box = [==[Brigadão, {name}! A primeira rodada é minha quando voltarmos pra forja.
Valeu demais, {name}. Agora cê tem amigos na montanha.
Valeu, {name}! Eu ia me virar sem isso, viu? Mas valeu.
Brigadão, {name}! Te daria um abraço, mas depois cê ia precisar de curador.
Opa, {name}, era só pedir. Agora não se mexe, que nem bigorna boa.
Nem precisa falar, {name}. Pedra e aço, lá vai!
Pede ajuda a um anão, {name}, e cê ganha. Aos berros.
Toma, {name}, um trocinho pra te manter de pé. Baixinho, igual eu.
Vai lá, {name}, firme feito a montanha.
Toma, {name}. A cerveja é pro depois; isso aqui é pro antes.
O Magni derreteria a coroa por um amigo, {name}. Essa é a opção mais em conta.
Pela Aliança, {name}! Força lá fora. Agora, mais força ainda.
Avante, {name}. A Aliança está com você.
Fica atrás de mim, {name}. É, eu sei. Agacha um pouco.
Combinado, {name}: eu vou na frente, cê pega o saque e depois a gente briga.
Se eu começar a cantar, {name}, o combate foi bem. Ou muito mal.
Juntos, ninguém nos derruba, {name}. Pela Aliança!
Certo, {name}: escudos no alto, cabeças baixas, e ninguém avança antes do plano.
Pedra e martelo te guardem, parente {name}!
Tome, {name}. Sobrou uma ideia e eu não tinha onde guardar.
Tome, {name}. Daria pão também, mas pão conjurado não tem gosto de nada.
Precisamos parar de nos encontrar assim, {name}. Pensando bem, não precisamos.
Em algum lugar aqui dentro um vilão ensaia um discurso, {name}. Vamos interromper.
Bom dia, {name}! Cedo demais pra cerveja. Quase. Toma isso antes.]==] },
	{ tag = "1.6.5", code = "zhCN", race = "Dwarf", faction = "Alliance", box = [==[多谢啦，{name}！回到熔炉边，头一轮酒俺请！
承情啦，{name}。山里从此多了你这个朋友！
谢啦，{name}！没它俺也扛得住，真的。不过还是谢啦！
好人哪，{name}！真想抱你一下，可抱完你得找治疗。
好嘞，{name}，开口就成。站着别动，跟块好铁砧似的。
甭多说，{name}。石头和钢铁作证，接好咯！
找矮人帮忙，{name}，准帮。就是嗓门大了点。
喏，{name}，一点小意思，保你站得稳。小，跟俺一个样。
去吧，{name}，稳如大山！
拿着，{name}。麦酒打完再喝，这个开打前用。
麦格尼会为朋友熔掉王冠，{name}。这个是平价版。
为了联盟，{name}！在外面挺住。现在更挺得住了。
前进吧，{name}。联盟与你同在。
站俺后头，{name}。嗯，俺知道。你蹲低点儿。
说好了，{name}：俺打头阵，你捡战利品，完事再吵。
要是俺唱起歌来，{name}，就是仗打得顺。或者糟透了。
团结一心，{name}。为了联盟！
听好，{name}：举盾，低头，计划没冲之前谁都不许冲。
愿石与锤护着你，老表{name}！
给，{name}。我多了个念头，正好没地方放。
拿着，{name}。本想加个面包，可造出来的面包没味儿。
我们不能再这样见面了，{name}。其实，也不是不行。
这里面有个反派正在排练台词，{name}。咱们去打断他。
早啊，{name}！喝麦酒还太早。就差一点。先来这个。]==] },
	{ tag = "1.6.5", code = "zhTW", race = "Dwarf", faction = "Alliance", box = [==[多謝啦，{name}！回熔爐頭一杯俺請！
夠意思，{name}！山裡從此有你這朋友！
謝啦，{name}！沒這個俺也行，真的！但還是謝啦。
好人哪，{name}！想抱你一下，但抱完你得找補師。
好咧，{name}，開口就成！站穩，像塊好鐵砧。
甭多說，{name}！岩石與鋼鐵，接著！
矮人有求必應，{name}。很大聲地應。
來，{name}，小小心意讓你站穩腳。小，跟俺一樣！
去吧，{name}，穩如磐石！
開打前用這個，{name}。麥酒打完再喝！
麥格尼願意為朋友熔掉王冠，{name}，這是平價版。
為了聯盟，{name}！挺住。現在更挺得住了。
前進吧，{name}。聯盟與你同在。
躲俺後面，{name}。對，俺知道。蹲低點。
好，{name}：俺打頭陣，你撿寶，打完再吵！
俺要是開唱，{name}，不是打得很順，就是很慘。
團結一心，{name}。為了聯盟！
聽好，{name}：舉盾、低頭，計畫沒動誰都別衝。
岩石與鐵錘保佑你，{name}兄弟！
給你，{name}。我多了一個念頭，沒地方放。
拿著，{name}。本想附麵包，但魔法麵包沒味道。
我們不能再這樣見面了，{name}。不對，當然可以。
某處有反派在排練台詞，{name}。去打斷他。
早，{name}！喝麥酒還太早。大概吧。先來這個！]==] },
	{ tag = "1.0.0-beta.9", code = "zhCN", race = "Troll", faction = "Horde", box = [==[你太客气咯，{name}！这个嘛，算我的。
小事一桩，{name}。别乱动咯。
洛阿在守着你咧，{name}。
为了部落，{name}！愿力量与你同行！
都准备好了？这下你也齐活了，{name}。]==] },
	{ tag = "1.0.0-beta.10", code = "koKR", race = "NightElf", faction = "Alliance", box = [==[Ishnu-alah, {name}. 당일에 갚다니, 칼도레이로선 서두른 셈이오.
기꺼이, {name}. 가만히, 달빛이 그대에게 닿도록.
Elune-adore, {name}. 사뿐히 걸으시오. 나무들은 잠귀가 밝으니.
얼라이언스를 위하여, {name}! 굳건히 버티시오. 이제 더 굳건히.
모두 준비됐소? 이제 {name}도 준비됐소.
여기, {name}. 생각이 하나 남는데 둘 데가 없어서.
이렇게 자꾸 만나면 곤란하오, {name}. 아니, 곤란할 거 없구려.
이 안 어딘가서 악당이 연설 연습 중이오, {name}. 가서 끊어 줍시다.]==] },
	{ tag = "1.5.0", code = "frFR", race = "Dwarf", faction = "Alliance", box = [==[Merci bien, {name} ! La première tournée est pour moi, de retour à la forge.
Pour sûr, {name}, suffisait d'demander. Bougez plus, comme une bonne enclume.
Tenez, {name}, un p'tit quelque chose pour vous garder d'aplomb. P'tit, comme moi.
Pour l'Alliance, {name} ! Restez fort là-dehors. Plus fort, désormais.
Tous prêts ? Vous l'êtes maintenant, {name}.
Tenez, {name}. J'avais une pensée en trop et nulle part où la ranger.
Il faut qu'on arrête de se croiser comme ça, {name}. En fait, non, pas du tout.
Quelque part ici, un méchant répète son discours, {name}. Interrompons-le.]==] },
	{ tag = "1.6.4", code = "esES", race = "Troll", faction = "Horde", box = [==[¡Ere' mu' amable, {name}! Esta va de mi parte.
¡Gracias, mon! Los espíritus te sonríen, {name}.
Me diste buen mojo, {name}. Ahora te lo devuelvo, extra picante, mon.
Bwonsamdi se va a llevar un buen chasco, {name}. Gracia', mon.
Claro, {name}. No te mueva': el mojo odia los blancos móviles.
Tranqui, {name}. Los loa te protegen.
Aléjate del vudú, {name}. ...Menos de este vudú. Este tá bien.
Lo' loa velan por ti, {name}. Son mu' fisgones, mon.
Ojo avizor ahí afuera, {name}. Llévate esto, mon.
Parece' alguien que aprecia la calidad, {name}. Toma: calidad.
Toma, {name}. Anda como si la selva fuera tuya. Como yo.
¡Por la Horda, {name}! Ve con fuerza. Acabo de darte un poco.
Ve con honor, {name}. La victoria te espera.
No te alejes, {name}. Un trol se regenera; lo' demás, cuidadito.
Este grupo tiene estilo, {name}. Y ahora también mojo.
Entramo' juntos, {name}, salimo' juntos. Ese e' to' el plan, mon.
Nuestra fuerza es la unión, {name}. ¡Por la Horda!
Adelante, {name}. La Horda avanza unida. ¿Retirarse? Oficialmente, nunca.
¡Eh, {name}! Siempre es bueno ver a la familia, mon.
Toma, {name}. Me sobraba una idea y no sabía dónde ponerla.
Toma, {name}. Añadiría pan, pero el pan conjurado no sabe a nada.
Tenemos que dejar de vernos así, {name}. Bueno, no, qué va.
Aquí dentro un villano ensaya su discurso, {name}. Vamos a interrumpirlo.
La noche e' la mejor hora pa'l mojo, {name}. Nadie ve de dónde sale.]==] },
}

local realFaction = rawget(_G, "UnitFactionGroup")

-- A session as that people and side on a client in that language.
local function oldBoxSession(scenario, case, locale)
	Mock.reset()
	Mock.playerRace = case.race
	Mock.class = "MAGE"
	Mock.locale = locale or case.code
	rawset(_G, "UnitFactionGroup", function(unit)
		if unit == "player" then return case.faction, case.faction end
		return nil
	end)
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		ns.db.profile.speech.presetChoice = "incharacter"
	end
	return ns
end

local function oldBoxDone()
	rawset(_G, "UnitFactionGroup", realFaction)
	Mock.locale = nil
end

for _, case in ipairs(SAVED) do
	local scenario = ("i18n-fix: old box: the %s box of a mage (%s %s) on a %s client still counts"):format(
		case.tag, case.faction, case.race, case.code)
	local ns = oldBoxSession(scenario, case)
	if ns then
		local ok, err = pcall(function()
			local RP = ns.InCharacter
			local speech = ns.db.profile.speech
			speech.phrases = case.box
			if not RP.Active(speech) then
				fail(scenario, "RP.Active says the box is the player's own lines, so In character stops")
			end
			ns.ClampSettings()
			if speech.phrases ~= RP.Text() then
				fail(scenario, "loading the profile left the box as it was instead of today's examples")
			end
			if not RP.Active(speech) then
				fail(scenario, "the box turned into today's examples and then stopped counting")
			end
		end)
		if not ok then fail(scenario, "threw: " .. ascii(err)) end
	end
	oldBoxDone()
end

-- Spanish has two clients and one file: a box filled in on esES is read on
-- esMX too, and the other way round.
do
	local case
	for _, saved in ipairs(SAVED) do
		if saved.code == "esES" and saved.tag == "1.6.5" then case = saved end
	end
	for _, locale in ipairs({ "esMX", "esES" }) do
		local scenario = "i18n-fix: old box: a Spanish box is read on " .. locale
		local ns = case and oldBoxSession(scenario, case, locale)
		if ns then
			local speech = ns.db.profile.speech
			speech.phrases = case.box
			if not ns.InCharacter.Active(speech) then
				fail(scenario, "RP.Active does not count a 1.6.5 Spanish box on " .. locale)
			end
		end
		oldBoxDone()
	end
end

-- What is not the set stays the player's own: an old box with one line
-- changed, one taken out, or one added is somebody's edit, however many of its
-- lines are an earlier translation.
do
	local case
	for _, saved in ipairs(SAVED) do
		if saved.code == "koKR" and saved.tag == "1.6.5" then case = saved end
	end
	local function lines(text)
		local out = {}
		for line in text:gmatch("[^\n]+") do out[#out + 1] = line end
		return out
	end
	local edits = {
		{ "a line of the player's own for one of the set's", function(t)
			t[5] = "Mine, {name}." return t end },
		{ "an old line gone", function(t) table.remove(t, 8) return t end },
		{ "a line added", function(t) t[#t + 1] = "Extra, {name}." return t end },
		{ "two lines swapped", function(t)
			t[1], t[2] = t[2], t[1] return t end },
	}
	for _, edit in ipairs(edits) do
		local scenario = "i18n-fix: old box: an old box with " .. edit[1] .. " is the player's own"
		local ns = case and oldBoxSession(scenario, case)
		if ns then
			local RP = ns.InCharacter
			local speech = ns.db.profile.speech
			local box = table.concat(edit[2](lines(case.box)), "\n")
			speech.phrases = box
			if RP.Active(speech) then
				fail(scenario, "RP.Active counts an edited box as the untouched set")
			end
			ns.ClampSettings()
			if speech.phrases ~= box then
				fail(scenario, "loading the profile rewrote the player's lines")
			end
		end
		oldBoxDone()
	end
end

-- The examples' translations as they read when RP.LEGACY_TRANSLATED was last
-- made: a digest of every example line of every people, side and class in each
-- language, and how many there are. A box keeps the language and the wording
-- it was saved in, so a translation of an example line edited since makes
-- every box saved before the edit read as the player's own lines, and In
-- character stops without a word for whoever updates over it: that is how
-- 1.6.6 broke the boxes of 1.6.5 and every release before it. The edit brings
-- the line it replaces into the table (python tools/legacy_lines.py --tags
-- <the last release> --check says what is missing, --lua prints the table;
-- python tools/audit_saved_boxes.py says whether every old box is known again),
-- and its new digest goes here. The same goes for new first lines in a pool,
-- which change the examples of the people who have it.
local EXAMPLES = {
	deDE = { 2143979529, 359 },
	esES = { 3871393207, 359 },
	frFR = { 3541006690, 359 },
	itIT = { 2183411623, 359 },
	koKR = { 476143163, 359 },
	ptBR = { 3295109827, 359 },
	zhCN = { 604202887, 359 },
	zhTW = { 1247806550, 359 },
}

local function examplesDigest(RP)
	local families, classes = { false }, { false }
	for family in pairs(RP.RACE) do families[#families + 1] = family end
	for class in pairs(RP.CLASS) do classes[#classes + 1] = class end
	local known, lines = {}, {}
	for _, faction in ipairs({ "Alliance", "Horde", "Neutral" }) do
		for _, family in ipairs(families) do
			for _, class in ipairs(classes) do
				for line in RP.Examples(family or nil, faction, class or nil):gmatch("[^\n]+") do
					if not known[line] then
						known[line] = true
						lines[#lines + 1] = line
					end
				end
			end
		end
	end
	-- A sum of one hash per line, so that no sort order (which the C library's
	-- locale decides) is in it.
	local sum = 0
	for _, line in ipairs(lines) do
		local h = 5381
		for i = 1, #line do h = (h * 33 + line:byte(i)) % 4294967296 end
		sum = (sum + h) % 4294967296
	end
	return sum, #lines
end

-- The table itself: every key is a line the language translates now, and
-- every earlier line is a different one, with its {name} to be filled in, so
-- an entry that matches nothing (a mistyped key) cannot sit in it unseen.
do
	local scenario = "i18n-fix: old box: every earlier translation belongs to a line translated now"
	local digestScenario = "i18n-fix: old box: the examples read as the table of earlier translations was made for"
	local codes = { "deDE", "esES", "frFR", "itIT", "koKR", "ptBR", "zhCN", "zhTW" }
	local seen = 0
	for _, code in ipairs(codes) do
		Mock.reset()
		Mock.locale = code
		local ns = load(scenario)
		if ns then
			local RP = ns.InCharacter
			local table_ = RP.LEGACY_TRANSLATED
			local set = table_ and table_[code]
			if not set then
				fail(scenario, "no earlier translations for " .. code)
			else
				for key, olds in pairs(set) do
					seen = seen + 1
					local now = rawget(ns.L, key)
					if now == nil then
						fail(scenario, ("%s: %s has no translation now"):format(code, ascii(key)))
					end
					for _, old in ipairs(olds) do
						if old == now then
							fail(scenario, ("%s: %s keeps the line it reads as today"):format(code, ascii(key)))
						end
						if old:find("{name}", 1, true) == nil and key:find("{name}", 1, true) ~= nil then
							fail(scenario, ("%s: an earlier line of %s lost its {name}: %s"):format(
								code, ascii(key), ascii(old)))
						end
					end
				end
			end
			local digest, count = examplesDigest(RP)
			local was = EXAMPLES[code]
			if not was or digest ~= was[1] or count ~= was[2] then
				fail(digestScenario, ("%s: the examples are %d lines with digest %.0f, not %s: an example line was "
					.. "translated again, or has a new first line -- see EXAMPLES in tests/scenarios/i18n-fixes.lua")
					:format(code, count, digest, was and (was[2] .. " with " .. was[1]) or "recorded"))
			end
		end
		Mock.locale = nil
	end
	if seen < 100 then fail(scenario, "only " .. seen .. " keys with an earlier translation") end
end
Mock.reset()

-- ------------------------------------------------------------------ i18n-fix 2
-- A whisper to somebody whose surname is not plain A to Z. Camelot, where
-- names have surnames; each is a person the current client whispers as the
-- person it names, which the first (plain letters) shows for control.

-- The client's walk as it reads since 70205, to say what it would send.
local function clientTarget(afterCommand)
	local target = afterCommand:match("%s*(.*)")
	local more = "[%s-](%S+)%s"
	if not target:find(more) then return nil end
	while target:find(more) do
		target = target:match("(.+)%s+[^%s]*")
	end
	return target
end

local function whisperSession(scenario, names, key)
	Mock.reset()
	Mock.setFlavour("camelot")
	local restore = H.strangers({ nameplate1 = names })
	local ns = load(scenario)
	if not ns then
		restore()
		return nil
	end
	H.freshPrompt(ns, scenario)
	local speech = ns.db.profile.speech
	speech.enabled = true
	speech.onlyWhenReturning = false
	speech.channel = "WHISPER"
	speech.phrases = "Thanks for the buff, {name}."
	H.owe(ns, key)
	ns.Prompt:InvalidateMacro()
	ns.addon:Tick()
	return ns, restore
end

local function spoken(text)
	for line in tostring(text or ""):gmatch("[^\n]+") do
		if not (line:find("^/target") or line:find("^/cast ")) then return line end
	end
	return nil
end

local WHISPERS = {
	{ { "Munin", "Hugins" }, "Munin Hugins", "plain letters" },
	{ { "Petra", "Br\195\162ve" }, "Petra Br\195\162ve", "an accented surname" },
	{ { "Maeve", "O'Neil" }, "Maeve O'Neil", "an apostrophe in the surname" },
	{ { "\235\175\188\236\136\152", "\234\185\128" }, "\235\175\188\236\136\152 \234\185\128", "a Korean name and surname" },
	{ { "\229\176\143\230\152\142", "\231\142\139" }, "\229\176\143\230\152\142 \231\142\139", "a Chinese name and surname" },
}

for _, case in ipairs(WHISPERS) do
	local names, key, what = case[1], case[2], case[3]
	local scenario = "i18n-fix: whisper: " .. what .. " is whispered as the person it names"
	local ns, restore = whisperSession(scenario, names, key)
	if ns then
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if not (text and text:find("/cast ", 1, true) and text:find(key, 1, true)) then
			fail(scenario, "SKIPPED -- " .. ascii(key) .. " is not armed: " .. ascii(text))
		else
			local line = spoken(text)
			local wanted = "/w " .. key .. " Thanks for the buff, " .. key .. "."
			local sent = clientTarget(wanted:match("^/%S+(.*)$"))
			if sent ~= key then
				fail(scenario, "SKIPPED -- the client itself would send " .. ascii(sent))
			elseif line ~= wanted then
				fail(scenario, ("the client would whisper %s, but the spoken line is %s, not %s"):format(
					ascii(key), ascii(line), ascii(wanted)))
			end
			-- The tooltip quotes the line without the name it goes to.
			local said = ns.SpokenText(line or "")
			if said ~= "Thanks for the buff, " .. key .. "." then
				fail(scenario, "the tooltip quotes " .. ascii(said))
			end
		end
		for _, e in ipairs(ns.errors or {}) do
			fail(scenario, "guarded: " .. tostring(e.where) .. " -> " .. tostring(e.err))
		end
		restore()
	end
end

-- Still silent where the client would misread the line: one word is a name
-- and the line's first word on a client with regional names.
do
	local scenario = "i18n-fix: whisper: a one-word name is still no whisper on Camelot"
	local ns, restore = whisperSession(scenario, { "Solo" }, "Solo")
	if ns then
		local text = ns.Prompt:GetButton():GetAttribute("macrotext1")
		if text and text:find("Solo", 1, true) and spoken(text) ~= nil then
			fail(scenario, "a whisper the client would send to somebody else: " .. ascii(spoken(text)))
		end
		restore()
	end
end
Mock.reset()

-- ------------------------------------------------------------------ i18n-fix 3
-- The end of a snooze on a 12-hour clock, written as the client writes it.
local CLOCKS = {
	{ "koKR", "\236\152\164\236\160\132 %d:%02d", "\236\152\164\237\155\132 %d:%02d" },
	{ "esES", "%d:%02d a.m.", "%d:%02d p.m." },
	{ "frFR", "%d:%02d du matin", "%d:%02d de l'apr\195\168s-midi" },
	-- Control: the language whose strings are the ones the code wrote.
	{ "deDE", "%d:%02d AM", "%d:%02d PM" },
}

local realGetCVar, realDate, realTime, realGameTime = _G.GetCVar, _G.date, _G.time, _G.GetGameTime
local WALL = 1790000000

local function clockSession(scenario, code, am, pm, cvars)
	Mock.reset()
	Mock.locale = code
	local ns = load(scenario)
	if ns then
		drive(scenario, ns)
		ns.Prompt:ExitTest()
		_G.date = os.date
		_G.time = function() return WALL end
		_G.GetCVar = function(name) return cvars[name] end
		rawset(_G, "TIME_TWELVEHOURAM", am)
		rawset(_G, "TIME_TWELVEHOURPM", pm)
		ns.StartSnooze(15)
	end
	return ns
end

local function clockDone(ns)
	if ns then ns.StopSnooze(true) end
	rawset(_G, "TIME_TWELVEHOURAM", nil)
	rawset(_G, "TIME_TWELVEHOURPM", nil)
	_G.GetCVar, _G.date, _G.time, _G.GetGameTime = realGetCVar, realDate, realTime, realGameTime
	Mock.locale = nil
end

-- The player's own clock (Local Time ticked, or a client that will not say).
for _, case in ipairs(CLOCKS) do
	local code, am, pm = case[1], case[2], case[3]
	local scenario = "i18n-fix: clock: a snooze ends on a " .. code .. " 12-hour clock as the client writes it"
	local ns = clockSession(scenario, code, am, pm, { timeMgrUseMilitaryTime = "0" })
	if ns then
		local got = tostring(ns.SnoozeEndsAt())
		local at = os.date("*t", WALL + 900)
		local hour = at.hour % 12
		if hour == 0 then hour = 12 end
		local want = (at.hour < 12 and am or pm):format(hour, at.min)
		if got ~= want then
			fail(scenario, ("the snooze is said to end at %s where the client's clock writes %s"):format(
				ascii(got), ascii(want)))
		end
	end
	clockDone(ns)
end

-- The realm clock the minimap shows by default: the hours either side of noon
-- and midnight, where a 12-hour clock says 12 and the marker turns over.
for _, case in ipairs({
	{ 0, 10, "\236\152\164\236\160\132 12:25" },
	{ 11, 50, "\236\152\164\237\155\132 12:05" },
	{ 12, 0, "\236\152\164\237\155\132 12:15" },
	{ 13, 20, "\236\152\164\237\155\132 1:35" },
	{ 23, 50, "\236\152\164\236\160\132 12:05" },
}) do
	local hour, minute, want = case[1], case[2], case[3]
	local scenario = ("i18n-fix: clock: a snooze ends on the realm clock at %d:%02d, in Korean"):format(hour, minute)
	local ns = clockSession(scenario, "koKR", "\236\152\164\236\160\132 %d:%02d", "\236\152\164\237\155\132 %d:%02d",
		{ timeMgrUseMilitaryTime = "0", timeMgrUseLocalTime = "0" })
	if ns then
		_G.GetGameTime = function() return hour, minute end
		local got = tostring(ns.SnoozeEndsAt())
		if got ~= want then
			fail(scenario, ("the snooze is said to end at %s, not %s"):format(ascii(got), ascii(want)))
		end
	end
	clockDone(ns)
end

-- A client with no such strings falls back to the English marker.
do
	local scenario = "i18n-fix: clock: a client without the 12-hour strings gets AM or PM"
	local ns = clockSession(scenario, "deDE", nil, nil, { timeMgrUseMilitaryTime = "0", timeMgrUseLocalTime = "0" })
	if ns then
		_G.GetGameTime = function() return 21, 40 end
		local got = tostring(ns.SnoozeEndsAt())
		if got ~= "9:55 PM" then fail(scenario, "the snooze is said to end at " .. ascii(got)) end
	end
	clockDone(ns)
end
Mock.reset()
