import re
import json

# Paste your raw text here
raw_data = """
Arab (171, 190, 152 )

Somalia: ( 102, 131, 171 )
Nigeria:
Igbo ( 160, 57, 150 )
Yaruba: ( 160, 57, 57 )
Hausa & Fulani ( 194, 122, 107 )

Cameroon:
Bantu: ( 24, 94, 97 )
Bamileke: ( 188, 90, 159)
Mbum: ( 188, 152, 154 )

Gabon:
Eshira: (65, 191, 19 )
Fang (57, 217, 219)
Omiene : (220, 93, 123 )
okande: (220, 191, 85 )
Bakote (57, 217, 104 )

congo:
sangha ( 209, 163, 120 )
makaa ( 129, 176, 168 )
mbere-nzabi (  129, 108, 168 )
teke: ( 91, 108, 101 )

DRC:
Lunda ( 152, 73, 188 )
Katanga ( 170, 26, 62 )
Lega (181, 104, 189 )
Mongo: ( 65, 104, 147 )
Kongo ( 196, 209, 49 )
Komo Birra ( 57, 104, 186 )
Zande (104, 93, 38 )
Bobangi ( 196, 168, 49 )
Gbaya (80, 134, 188 )

South Africa: 
afrikaan ( 210, 165, 108 )
xhosa ( 175, 145, 109 )
Zulu: ( 210, 114, 108 )
Sesotho ( 58, 158, 68 )
Tsawna ( 210, 201, 108 )
Swasi ( 210, 127, 176 )
North Sotho (136, 211, 178)

Angola
Kimbudu: ( 134, 180, 149 )
herero: ( 255, 196, 0 )
Ganguela ( 142, 119., 0 )

Namibia
Himba ( 193, 57, 83 )
Lozi ( 193, 217, 167 )
Baster ( 193. 217, 222 )
Nama ( 193, 119, 60 )

Zimbawe:
Shona ( 80, 158, 93 )
Northen Ndebele ( 173, 145, 93 )
TSWA ( 170, 80, 20 )

Mozambiue
Tsonnga ( 14, 54, 189 )
Xona-Karanga ( 14, 137, 62 )
Maravi (119, 62, 122 )
Loka-lomwe ( 30, 115, 132 )
Makonde ( 14, 54, 62 )

Zambia
Mamba ( 201, 209, 0 )
Tonga ( 221, 97, 190 )
Luyana (221, 97, 190 )

Malawi
chewa ( 161, 84, 104 )
Tumbuka ( 135, 145, 88 )

Central African Republic
Northen CAR group ( 165, 108, 67 )
Gbaya ( 26, 153, 104 )
Banda ( 150, 70, 90 )
Nzakara ( 211, 150, 165 )

Tanzania:
rufiji ( 103, 135, 146 )
Turu ( 52, 78, 191 )
mwanga ( 255, 233, 127 )
Fipa (98, 170, 85 )
ngoni (103, 91, 146 )
Makonde (235, 135, 127 )
sukuma (137, 179, 193 )

Uganda
Bantu (104, 67, 57 )
Central Sudanic (255, 255, 91 )

Kenya
Bantu ( 131, 54, 64 )
Mili-Hmitic (191,140,64 )
Nilotic ( 59, 158, 191 )
Kamba (131, 209, 64 )

ethiopia:
comoros (48, 129, 57 )
Aaris ( 188, 49, 167 )
Tigrayans ( 255, 191, 39 )
amharas ( 255, 135, 195 )
afars ( 255, 39, 195 )

South Sudan
 Nuer ( 150, 134, 142 )
dinka ( 212, 186, 173 )
bari (212, 191, 110 )
azande (211, 85, 160 )
bande ( 211, 85, 71 )
berti (212, 137, 110 )
berta (211, 140, 71 )

muslims
Cristian minotiry ( 187, 170, 126 )

Sudan
dago ( 171, 204, 42 )
moro bamgetu (111, 127, 186 )
koalib tagoi ( 12, 101, 160 )
shilluk  (206, 125, 194 )
Beja (12, 155, 160 )

Niger:
Tuareg ( 38, 88, 77 )
Hausa ( 255, 57, 0 )
Kanura ( 255, 124, 0 )
zerma-somghani ( 255, 216, 0 )

Mali
Amazigh ( 101, 152, 211 )
Fulani ( 158, 138, 87 )
Bomu  ( 62, 216, 0 )
bambara ( 255, 216, 0 )
malinke ( 214, 138, 67 )

Burkina Faso
Mossi (152, 152, 211 )
Senofu (145, 114, 0 )
marka (202, 110, 75 )
peuls ( 86, 77, 209 )

Ivory Coast
Mande ( 181, 93, 85 )
Krou ( 57, 106, 255 )
akan ( 132, 204, 255 )
voltaiqe (181, 163, 85 )

sierra leone
Mende (114, 212, 190 )
sherbor (114, 159, 116 )

Guinea:
Soussou ( 82, 127, 117 )
Peul ( 225, 250, 155 )
Malinke ( 117, 181, 166 )
kpelle (32, 168, 78 )

Senagal
Wolofia ( 137, 206, 255 )
Diola ( 183, 151, 64 )
Pular ( 255, 216, 0 )
Serer ( 150, 137, 72 )

Algeria
Berbers ( 255, 204, 255 )

Europe:
French (61, 204, 255 )
Germans ( 73, 72, 77 )
Italians (67, 127, 63 )
Poles ( 197, 92, 106 )
Dutch ( 199, 135, 73 )
Ukranian ( 52, 88, 138 )
Spaniards ( 242, 205, 94 )
Czech ( 54, 167, 156 )
Hungarians ( 78, 125, 115 )
Serbs ( 78, 125, 115 )
Croat ( 42, 45, 96 )
Slovenes ( 79, 111, 150 )
Bosnians( 223, 193, 135 )
Hellenics ( 93, 181, 227 )
Albanians ( 149, 45, 102 )
Bulgarians ( 51, 155, 0 )
Turks ( 166, 52, 67 )
Romanian (215, 196, 72 )
Gagauz Turks (160, 0, 0 )
Macedonians ( 202, 149, 118 )
Slovaks ( 121, 92, 159 )
carpanthian Russ ( 78, 183, 115 )
Berlarussians ( 199, 213, 224 )
Lithuanian (219, 219, 119 )
Latvia ( 75, 77, 186 )
Estonia ( 50, 135, 175 )
Denmark ( 153, 116, 93 )
Norway ( 111, 71, 71 )
Sweden ( 36, 132, 247 )
Finnish ( 194, 198, 215 )
Basque ( 106, 205, 147 )
Catalonians ( 242, 93, 155 )
English (200, 56, 93 )
Scottish ( 75, 122, 193 )
Welish ( 255, 181, 147 )
Irish ( 80, 159, 80 )
Romanch ( 178, 85, 150 )
Portougesse ( 73, 183, 77 )
Icelandish ( 68, 81, 113 )
Georgia ( 239, 228, 232 )
Armenia (246, 162, 134 )
Checnyians ( 93, 158,93 )
Dagestanians ( 124, 140, 124 )
Azerbis ( 114, 140, 217 )
Kalmykians ( 191, 189, 37 )
Russians (56, 96, 56 )
Komi ( 56, 96, 158 )
Nenets ( 255, 216, 0 )
Tuvans ( 255, 158, 0 )
Altayns ( 56, 194, 56 )
Evenkis ( 0, 158, 170 )
Yakuts (0, 158, 109 )
Evens ( 147, 152, 132 )
Chukoktans ( 0, 0, 109 )
Udegens ( 209, 211, 97 )
Balkarsk ( 101,158, 0 )
Tartars (56, 140, 88 )
Mari (111,70, 158 )
Chuvash ( 151, 175, 160 )
Mordvins ( 111, 70, 67 )
Mongols ( 163, 142, 75 )
Tibetans ( 80, 118, 45 )
East Turks ( 238, 218, 218 )
Koreans ( 94, 118, 190 )
Japanase ( 255, 201, 178 )
Han Chinise ( 167, 87, 90 )
Yunnans ( 167, 170, 90 )
Vietnam ( 198, 190, 117 )
Thai ( 20, 45, 76 )
Myammar ( 59, 113, 79 )
Malaya(197, 96, 100 )
Bengal (0, 91, 102 )
Khazaks ( 88, 161, 193 )
Uzebeks (202, 206, 253 )
Kirghiz ( 244, 61, 111 )
Turkmen (189, 140, 110 )
Tajiks (109, 148, 130 )
Hazara ( 58, 117, 89 )
Pashtuns ( 168, 114, 60 )
Kurds ( 204, 172, 120 )
Assyrians ( 120,79, 209 )
Persians ( 90, 143, 123 )
Balochs ( 160, 79, 41 )
Lurs ( 153, 42, 175 )
Sindhi (138, 226, 185 )
Pashtu ( 209, 84, 214 )
Saeaikis ( 110, 124, 0 )
Punjabs ( 226, 113, 0 )
Chitrall ( 127, 115,109 )
Kashmiri ( 175, 93, 42 )

India:
Malayalam ( 154, 155, 152 )
Tami (229, 195, 156 )
kannada (48, 104, 31 )
Marathi ( 196, 152, 102 )
Gukarati ( 49,105, 119 )
Odia (104, 145, 114 )
Ladakashi ( 160, 163, 108 )
Teiugu (104, 196, 68 )
Sikinn (153, 168, 138 )
Assamese ( 66, 176, 155 )
Adi (188, 160, 83 )
Chakma (88, 163, 108 )
Mizo ( 137, 116, 127 )
Tada ( 137, 116, 176 )
Marwais ( 140, 181, 134 )
Kinnauris ( 208, 207, 108 )
Gond (208, 163, 199 )
Bhils(91, 127, 0 )
Saraikis ( 204,237, 65 )
BBagris ( 217, 140, 94 )
Nimads (175, 87, 171 )
bundelis (175, 176, 171 )
Chhattisgrahiya (255, 233, 127 )
Baghelis ( 175, 123, 173 )
Magahis (127, 106, 0 )
Kaurais (208, 124, 108 )
Kannaujis (57, 105, 163 )
Awashis (57, 196, 111 )
Maithils (152, 56, 147 )

Indonesia:
Acio (255,141, 66 )
Batak ( 165, 70, 85 )
Malau (193, 145, 143 )
Banjarese (60, 129, 86 )
Minangkabau (255, 228, 94 )
Rejang (191, 119, 39 )
Javaenese (140, 198, 139 )
Batanese (55, 211, 211 )
Javanese (221, 178, 150 )
Atoni ( 49, 183, 152 )
mollucans ( 59, 221, 184 )
Tolaki (191, 206, 75 )
Bugis ( 221, 142, 15 )
kaili ( 98, 98, 0 )
Gorontalo ( 234, 202, 157 )
Mihanasa (181, 48, 75 )
Tobelo (221, 147, 196 )
Papuans ( 155, 142, 137 )
Osapminlk ( 221, 80, 114 )
Angan ( 43, 56, 90 )

Inuit ( 255, 127, 88 )
Quebecs ( 61, 168, 232 )
Brazilian Natives (195, 92, 109 )
"""

def clean_to_json(text):
    # Regex breakdown:
    # ([\w\s&-]+) -> Captures name (letters, spaces, ampersands, dashes)
    # :? \s* -> Handles optional colons and spaces
    # \( \s* (\d+), \s* (\d+), \s* (\d+) \s* \) -> Captures the 3 RGB numbers
    pattern = r"([\w\s&-]+):?\s*\(\s*(\d+),\s*(\d+),\s*(\d+)\s*\)"
    
    matches = re.findall(pattern, text)
    
    result_map = {}
    for name, r, g, b in matches:
        # Format key as "(R, G, B)" to match your Godot logic
        key = f"({r.strip()}, {g.strip()}, {b.strip()})"
        result_map[key] = name.strip()

    return json.dumps(result_map, indent=4)

# Run and save
json_output = clean_to_json(raw_data)
with open("ethnicitiesFix.json", "w") as f:
    f.write(json_output)

print("File 'ethnicities.json' created successfully!")
