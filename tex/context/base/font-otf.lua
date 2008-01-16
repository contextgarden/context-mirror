if not modules then modules = { } end modules ['font-otf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- the flattening code is a prelude to a more compact table format (so, we're now
-- at the fourth version)

--- todo: featuredata is now indexed by kind,lookup but probably lookup is okay too

-- todo: now that we pack ... resolve strings to unicode points
-- todo: unpack already in tmc file, i.e. save tables and return ref''d version
-- todo: dependents etc resolve too, maybe even reorder glyphs to unicode
-- todo: pack ignoreflags

-- abvf abvs blwf blwm blws dist falt half halt jalt lfbd ljmo
-- mset opbd palt pwid qwid rand rtbd rtla ruby size tjmo twid valt vatu vert
-- vhal vjmo vkna vkrn vpal vrt2

--[[ldx--
<p>This module is sparsely documented because it is a moving target.
The table format of the reader changes and we experiment a lot with
different methods for supporting features.</p>

<p>As with the <l n='afm'/> code, we may decide to store more information
in the <l n='otf'/> table.</p>

<p>Incrementing the version number will force a re-cache. We jump the
number by one when there's a fix in the <l n='fontforge'/> library or
<l n='lua'/> code that results in different tables.</p>
--ldx]]--

--~ The node based processing functions look quite complex which is mainly due to
--~ the fact that we need to share data and cache resolved issues (saves much memory and
--~ is also faster). A further complication is that we support static as well as dynamic
--~ features.

fonts                        = fonts or { }
fonts.otf                    = fonts.otf or { }
fonts.otf.version            = 2.05
fonts.otf.pack               = true
fonts.otf.tables             = fonts.otf.tables or { }
fonts.otf.meanings           = fonts.otf.meanings or { }
fonts.otf.enhance_data       = false
fonts.otf.syncspace          = true
fonts.otf.features           = { }
fonts.otf.features.aux       = { }
fonts.otf.features.data      = { }
fonts.otf.features.list      = { } -- not (yet) used, oft fonts have gpos/gsub lists
fonts.otf.features.default   = { }
fonts.otf.trace_features     = false
fonts.otf.trace_set_features = false
fonts.otf.trace_replacements = false
fonts.otf.trace_contexts     = false
fonts.otf.trace_anchors      = false
fonts.otf.trace_ligatures    = false
fonts.otf.trace_kerns        = false
fonts.otf.notdef             = false
fonts.otf.cache              = containers.define("fonts", "otf", fonts.otf.version, true)

--[[ldx--
<p>We start with a lot of tables and related functions.</p>
--ldx]]--

fonts.otf.tables.scripts = {
    ['dflt'] = 'Default',

    ['arab'] = 'Arabic',
    ['armn'] = 'Armenian',
    ['bali'] = 'Balinese',
    ['beng'] = 'Bengali',
    ['bopo'] = 'Bopomofo',
    ['brai'] = 'Braille',
    ['bugi'] = 'Buginese',
    ['buhd'] = 'Buhid',
    ['byzm'] = 'Byzantine Music',
    ['cans'] = 'Canadian Syllabics',
    ['cher'] = 'Cherokee',
    ['copt'] = 'Coptic',
    ['cprt'] = 'Cypriot Syllabary',
    ['cyrl'] = 'Cyrillic',
    ['deva'] = 'Devanagari',
    ['dsrt'] = 'Deseret',
    ['ethi'] = 'Ethiopic',
    ['geor'] = 'Georgian',
    ['glag'] = 'Glagolitic',
    ['goth'] = 'Gothic',
    ['grek'] = 'Greek',
    ['gujr'] = 'Gujarati',
    ['guru'] = 'Gurmukhi',
    ['hang'] = 'Hangul',
    ['hani'] = 'CJK Ideographic',
    ['hano'] = 'Hanunoo',
    ['hebr'] = 'Hebrew',
    ['ital'] = 'Old Italic',
    ['jamo'] = 'Hangul Jamo',
    ['java'] = 'Javanese',
    ['kana'] = 'Hiragana and Katakana',
    ['khar'] = 'Kharosthi',
    ['khmr'] = 'Khmer',
    ['knda'] = 'Kannada',
    ['lao' ] = 'Lao',
    ['latn'] = 'Latin',
    ['limb'] = 'Limbu',
    ['linb'] = 'Linear B',
    ['math'] = 'Mathematical Alphanumeric Symbols',
    ['mlym'] = 'Malayalam',
    ['mong'] = 'Mongolian',
    ['musc'] = 'Musical Symbols',
    ['mymr'] = 'Myanmar',
    ['nko' ] = "N'ko",
    ['ogam'] = 'Ogham',
    ['orya'] = 'Oriya',
    ['osma'] = 'Osmanya',
    ['phag'] = 'Phags-pa',
    ['phnx'] = 'Phoenician',
    ['runr'] = 'Runic',
    ['shaw'] = 'Shavian',
    ['sinh'] = 'Sinhala',
    ['sylo'] = 'Syloti Nagri',
    ['syrc'] = 'Syriac',
    ['tagb'] = 'Tagbanwa',
    ['tale'] = 'Tai Le',
    ['talu'] = 'Tai Lu',
    ['taml'] = 'Tamil',
    ['telu'] = 'Telugu',
    ['tfng'] = 'Tifinagh',
    ['tglg'] = 'Tagalog',
    ['thaa'] = 'Thaana',
    ['thai'] = 'Thai',
    ['tibt'] = 'Tibetan',
    ['ugar'] = 'Ugaritic Cuneiform',
    ['xpeo'] = 'Old Persian Cuneiform',
    ['xsux'] = 'Sumero-Akkadian Cuneiform',
    ['yi'  ] = 'Yi'
}

fonts.otf.tables.languages = {
    ['dflt'] = 'Default',

    ['aba'] = 'Abaza',
    ['abk'] = 'Abkhazian',
    ['ady'] = 'Adyghe',
    ['afk'] = 'Afrikaans',
    ['afr'] = 'Afar',
    ['agw'] = 'Agaw',
    ['als'] = 'Alsatian',
    ['alt'] = 'Altai',
    ['amh'] = 'Amharic',
    ['ara'] = 'Arabic',
    ['ari'] = 'Aari',
    ['ark'] = 'Arakanese',
    ['asm'] = 'Assamese',
    ['ath'] = 'Athapaskan',
    ['avr'] = 'Avar',
    ['awa'] = 'Awadhi',
    ['aym'] = 'Aymara',
    ['aze'] = 'Azeri',
    ['bad'] = 'Badaga',
    ['bag'] = 'Baghelkhandi',
    ['bal'] = 'Balkar',
    ['bau'] = 'Baule',
    ['bbr'] = 'Berber',
    ['bch'] = 'Bench',
    ['bcr'] = 'Bible Cree',
    ['bel'] = 'Belarussian',
    ['bem'] = 'Bemba',
    ['ben'] = 'Bengali',
    ['bgr'] = 'Bulgarian',
    ['bhi'] = 'Bhili',
    ['bho'] = 'Bhojpuri',
    ['bik'] = 'Bikol',
    ['bil'] = 'Bilen',
    ['bkf'] = 'Blackfoot',
    ['bli'] = 'Balochi',
    ['bln'] = 'Balante',
    ['blt'] = 'Balti',
    ['bmb'] = 'Bambara',
    ['bml'] = 'Bamileke',
    ['bos'] = 'Bosnian',
    ['bre'] = 'Breton',
    ['brh'] = 'Brahui',
    ['bri'] = 'Braj Bhasha',
    ['brm'] = 'Burmese',
    ['bsh'] = 'Bashkir',
    ['bti'] = 'Beti',
    ['cat'] = 'Catalan',
    ['ceb'] = 'Cebuano',
    ['che'] = 'Chechen',
    ['chg'] = 'Chaha Gurage',
    ['chh'] = 'Chattisgarhi',
    ['chi'] = 'Chichewa',
    ['chk'] = 'Chukchi',
    ['chp'] = 'Chipewyan',
    ['chr'] = 'Cherokee',
    ['chu'] = 'Chuvash',
    ['cmr'] = 'Comorian',
    ['cop'] = 'Coptic',
    ['cos'] = 'Corsican',
    ['cre'] = 'Cree',
    ['crr'] = 'Carrier',
    ['crt'] = 'Crimean Tatar',
    ['csl'] = 'Church Slavonic',
    ['csy'] = 'Czech',
    ['dan'] = 'Danish',
    ['dar'] = 'Dargwa',
    ['dcr'] = 'Woods Cree',
    ['deu'] = 'German',
    ['dgr'] = 'Dogri',
    ['div'] = 'Divehi',
    ['djr'] = 'Djerma',
    ['dng'] = 'Dangme',
    ['dnk'] = 'Dinka',
    ['dri'] = 'Dari',
    ['dun'] = 'Dungan',
    ['dzn'] = 'Dzongkha',
    ['ebi'] = 'Ebira',
    ['ecr'] = 'Eastern Cree',
    ['edo'] = 'Edo',
    ['efi'] = 'Efik',
    ['ell'] = 'Greek',
    ['eng'] = 'English',
    ['erz'] = 'Erzya',
    ['esp'] = 'Spanish',
    ['eti'] = 'Estonian',
    ['euq'] = 'Basque',
    ['evk'] = 'Evenki',
    ['evn'] = 'Even',
    ['ewe'] = 'Ewe',
    ['fan'] = 'French Antillean',
    ['far'] = 'Farsi',
    ['fin'] = 'Finnish',
    ['fji'] = 'Fijian',
    ['fle'] = 'Flemish',
    ['fne'] = 'Forest Nenets',
    ['fon'] = 'Fon',
    ['fos'] = 'Faroese',
    ['fra'] = 'French',
    ['fri'] = 'Frisian',
    ['frl'] = 'Friulian',
    ['fta'] = 'Futa',
    ['ful'] = 'Fulani',
    ['gad'] = 'Ga',
    ['gae'] = 'Gaelic',
    ['gag'] = 'Gagauz',
    ['gal'] = 'Galician',
    ['gar'] = 'Garshuni',
    ['gaw'] = 'Garhwali',
    ['gez'] = "Ge'ez",
    ['gil'] = 'Gilyak',
    ['gmz'] = 'Gumuz',
    ['gon'] = 'Gondi',
    ['grn'] = 'Greenlandic',
    ['gro'] = 'Garo',
    ['gua'] = 'Guarani',
    ['guj'] = 'Gujarati',
    ['hai'] = 'Haitian',
    ['hal'] = 'Halam',
    ['har'] = 'Harauti',
    ['hau'] = 'Hausa',
    ['haw'] = 'Hawaiin',
    ['hbn'] = 'Hammer-Banna',
    ['hil'] = 'Hiligaynon',
    ['hin'] = 'Hindi',
    ['hma'] = 'High Mari',
    ['hnd'] = 'Hindko',
    ['ho']  = 'Ho',
    ['hri'] = 'Harari',
    ['hrv'] = 'Croatian',
    ['hun'] = 'Hungarian',
    ['hye'] = 'Armenian',
    ['ibo'] = 'Igbo',
    ['ijo'] = 'Ijo',
    ['ilo'] = 'Ilokano',
    ['ind'] = 'Indonesian',
    ['ing'] = 'Ingush',
    ['inu'] = 'Inuktitut',
    ['iri'] = 'Irish',
    ['irt'] = 'Irish Traditional',
    ['isl'] = 'Icelandic',
    ['ism'] = 'Inari Sami',
    ['ita'] = 'Italian',
    ['iwr'] = 'Hebrew',
    ['jan'] = 'Japanese',
    ['jav'] = 'Javanese',
    ['jii'] = 'Yiddish',
    ['jud'] = 'Judezmo',
    ['jul'] = 'Jula',
    ['kab'] = 'Kabardian',
    ['kac'] = 'Kachchi',
    ['kal'] = 'Kalenjin',
    ['kan'] = 'Kannada',
    ['kar'] = 'Karachay',
    ['kat'] = 'Georgian',
    ['kaz'] = 'Kazakh',
    ['keb'] = 'Kebena',
    ['kge'] = 'Khutsuri Georgian',
    ['kha'] = 'Khakass',
    ['khk'] = 'Khanty-Kazim',
    ['khm'] = 'Khmer',
    ['khs'] = 'Khanty-Shurishkar',
    ['khv'] = 'Khanty-Vakhi',
    ['khw'] = 'Khowar',
    ['kik'] = 'Kikuyu',
    ['kir'] = 'Kirghiz',
    ['kis'] = 'Kisii',
    ['kkn'] = 'Kokni',
    ['klm'] = 'Kalmyk',
    ['kmb'] = 'Kamba',
    ['kmn'] = 'Kumaoni',
    ['kmo'] = 'Komo',
    ['kms'] = 'Komso',
    ['knr'] = 'Kanuri',
    ['kod'] = 'Kodagu',
    ['koh'] = 'Korean Old Hangul',
    ['kok'] = 'Konkani',
    ['kon'] = 'Kikongo',
    ['kop'] = 'Komi-Permyak',
    ['kor'] = 'Korean',
    ['koz'] = 'Komi-Zyrian',
    ['kpl'] = 'Kpelle',
    ['kri'] = 'Krio',
    ['krk'] = 'Karakalpak',
    ['krl'] = 'Karelian',
    ['krm'] = 'Karaim',
    ['krn'] = 'Karen',
    ['krt'] = 'Koorete',
    ['ksh'] = 'Kashmiri',
    ['ksi'] = 'Khasi',
    ['ksm'] = 'Kildin Sami',
    ['kui'] = 'Kui',
    ['kul'] = 'Kulvi',
    ['kum'] = 'Kumyk',
    ['kur'] = 'Kurdish',
    ['kuu'] = 'Kurukh',
    ['kuy'] = 'Kuy',
    ['kyk'] = 'Koryak',
    ['lad'] = 'Ladin',
    ['lah'] = 'Lahuli',
    ['lak'] = 'Lak',
    ['lam'] = 'Lambani',
    ['lao'] = 'Lao',
    ['lat'] = 'Latin',
    ['laz'] = 'Laz',
    ['lcr'] = 'L-Cree',
    ['ldk'] = 'Ladakhi',
    ['lez'] = 'Lezgi',
    ['lin'] = 'Lingala',
    ['lma'] = 'Low Mari',
    ['lmb'] = 'Limbu',
    ['lmw'] = 'Lomwe',
    ['lsb'] = 'Lower Sorbian',
    ['lsm'] = 'Lule Sami',
    ['lth'] = 'Lithuanian',
    ['ltz'] = 'Luxembourgish',
    ['lub'] = 'Luba',
    ['lug'] = 'Luganda',
    ['luh'] = 'Luhya',
    ['luo'] = 'Luo',
    ['lvi'] = 'Latvian',
    ['maj'] = 'Majang',
    ['mak'] = 'Makua',
    ['mal'] = 'Malayalam Traditional',
    ['man'] = 'Mansi',
    ['map'] = 'Mapudungun',
    ['mar'] = 'Marathi',
    ['maw'] = 'Marwari',
    ['mbn'] = 'Mbundu',
    ['mch'] = 'Manchu',
    ['mcr'] = 'Moose Cree',
    ['mde'] = 'Mende',
    ['men'] = "Me'en",
    ['miz'] = 'Mizo',
    ['mkd'] = 'Macedonian',
    ['mle'] = 'Male',
    ['mlg'] = 'Malagasy',
    ['mln'] = 'Malinke',
    ['mlr'] = 'Malayalam Reformed',
    ['mly'] = 'Malay',
    ['mnd'] = 'Mandinka',
    ['mng'] = 'Mongolian',
    ['mni'] = 'Manipuri',
    ['mnk'] = 'Maninka',
    ['mnx'] = 'Manx Gaelic',
    ['moh'] = 'Mohawk',
    ['mok'] = 'Moksha',
    ['mol'] = 'Moldavian',
    ['mon'] = 'Mon',
    ['mor'] = 'Moroccan',
    ['mri'] = 'Maori',
    ['mth'] = 'Maithili',
    ['mts'] = 'Maltese',
    ['mun'] = 'Mundari',
    ['nag'] = 'Naga-Assamese',
    ['nan'] = 'Nanai',
    ['nas'] = 'Naskapi',
    ['ncr'] = 'N-Cree',
    ['ndb'] = 'Ndebele',
    ['ndg'] = 'Ndonga',
    ['nep'] = 'Nepali',
    ['new'] = 'Newari',
    ['ngr'] = 'Nagari',
    ['nhc'] = 'Norway House Cree',
    ['nis'] = 'Nisi',
    ['niu'] = 'Niuean',
    ['nkl'] = 'Nkole',
    ['nko'] = "N'ko",
    ['nld'] = 'Dutch',
    ['nog'] = 'Nogai',
    ['nor'] = 'Norwegian',
    ['nsm'] = 'Northern Sami',
    ['nta'] = 'Northern Tai',
    ['nto'] = 'Esperanto',
    ['nyn'] = 'Nynorsk',
    ['oci'] = 'Occitan',
    ['ocr'] = 'Oji-Cree',
    ['ojb'] = 'Ojibway',
    ['ori'] = 'Oriya',
    ['oro'] = 'Oromo',
    ['oss'] = 'Ossetian',
    ['paa'] = 'Palestinian Aramaic',
    ['pal'] = 'Pali',
    ['pan'] = 'Punjabi',
    ['pap'] = 'Palpa',
    ['pas'] = 'Pashto',
    ['pgr'] = 'Polytonic Greek',
    ['pil'] = 'Pilipino',
    ['plg'] = 'Palaung',
    ['plk'] = 'Polish',
    ['pro'] = 'Provencal',
    ['ptg'] = 'Portuguese',
    ['qin'] = 'Chin',
    ['raj'] = 'Rajasthani',
    ['rbu'] = 'Russian Buriat',
    ['rcr'] = 'R-Cree',
    ['ria'] = 'Riang',
    ['rms'] = 'Rhaeto-Romanic',
    ['rom'] = 'Romanian',
    ['roy'] = 'Romany',
    ['rsy'] = 'Rusyn',
    ['rua'] = 'Ruanda',
    ['rus'] = 'Russian',
    ['sad'] = 'Sadri',
    ['san'] = 'Sanskrit',
    ['sat'] = 'Santali',
    ['say'] = 'Sayisi',
    ['sek'] = 'Sekota',
    ['sel'] = 'Selkup',
    ['sgo'] = 'Sango',
    ['shn'] = 'Shan',
    ['sib'] = 'Sibe',
    ['sid'] = 'Sidamo',
    ['sig'] = 'Silte Gurage',
    ['sks'] = 'Skolt Sami',
    ['sky'] = 'Slovak',
    ['sla'] = 'Slavey',
    ['slv'] = 'Slovenian',
    ['sml'] = 'Somali',
    ['smo'] = 'Samoan',
    ['sna'] = 'Sena',
    ['snd'] = 'Sindhi',
    ['snh'] = 'Sinhalese',
    ['snk'] = 'Soninke',
    ['sog'] = 'Sodo Gurage',
    ['sot'] = 'Sotho',
    ['sqi'] = 'Albanian',
    ['srb'] = 'Serbian',
    ['srk'] = 'Saraiki',
    ['srr'] = 'Serer',
    ['ssl'] = 'South Slavey',
    ['ssm'] = 'Southern Sami',
    ['sur'] = 'Suri',
    ['sva'] = 'Svan',
    ['sve'] = 'Swedish',
    ['swa'] = 'Swadaya Aramaic',
    ['swk'] = 'Swahili',
    ['swz'] = 'Swazi',
    ['sxt'] = 'Sutu',
    ['syr'] = 'Syriac',
    ['tab'] = 'Tabasaran',
    ['taj'] = 'Tajiki',
    ['tam'] = 'Tamil',
    ['tat'] = 'Tatar',
    ['tcr'] = 'TH-Cree',
    ['tel'] = 'Telugu',
    ['tgn'] = 'Tongan',
    ['tgr'] = 'Tigre',
    ['tgy'] = 'Tigrinya',
    ['tha'] = 'Thai',
    ['tht'] = 'Tahitian',
    ['tib'] = 'Tibetan',
    ['tkm'] = 'Turkmen',
    ['tmn'] = 'Temne',
    ['tna'] = 'Tswana',
    ['tne'] = 'Tundra Nenets',
    ['tng'] = 'Tonga',
    ['tod'] = 'Todo',
    ['trk'] = 'Turkish',
    ['tsg'] = 'Tsonga',
    ['tua'] = 'Turoyo Aramaic',
    ['tul'] = 'Tulu',
    ['tuv'] = 'Tuvin',
    ['twi'] = 'Twi',
    ['udm'] = 'Udmurt',
    ['ukr'] = 'Ukrainian',
    ['urd'] = 'Urdu',
    ['usb'] = 'Upper Sorbian',
    ['uyg'] = 'Uyghur',
    ['uzb'] = 'Uzbek',
    ['ven'] = 'Venda',
    ['vit'] = 'Vietnamese',
    ['wa' ] = 'Wa',
    ['wag'] = 'Wagdi',
    ['wcr'] = 'West-Cree',
    ['wel'] = 'Welsh',
    ['wlf'] = 'Wolof',
    ['xbd'] = 'Tai Lue',
    ['xhs'] = 'Xhosa',
    ['yak'] = 'Yakut',
    ['yba'] = 'Yoruba',
    ['ycr'] = 'Y-Cree',
    ['yic'] = 'Yi Classic',
    ['yim'] = 'Yi Modern',
    ['zhh'] = 'Chinese Hong Kong',
    ['zhp'] = 'Chinese Phonetic',
    ['zhs'] = 'Chinese Simplified',
    ['zht'] = 'Chinese Traditional',
    ['znd'] = 'Zande',
    ['zul'] = 'Zulu'
}

fonts.otf.tables.features = {
    ['aalt'] = 'Access All Alternates',
    ['abvf'] = 'Above-Base Forms',
    ['abvm'] = 'Above-Base Mark Positioning',
    ['abvs'] = 'Above-Base Substitutions',
    ['afrc'] = 'Alternative Fractions',
    ['akhn'] = 'Akhands',
    ['blwf'] = 'Below-Base Forms',
    ['blwm'] = 'Below-Base Mark Positioning',
    ['blws'] = 'Below-Base Substitutions',
    ['c2pc'] = 'Petite Capitals From Capitals',
    ['c2sc'] = 'Small Capitals From Capitals',
    ['calt'] = 'Contextual Alternates',
    ['case'] = 'Case-Sensitive Forms',
    ['ccmp'] = 'Glyph Composition/Decomposition',
    ['cjct'] = 'Conjunct Forms',
    ['clig'] = 'Contextual Ligatures',
    ['cpsp'] = 'Capital Spacing',
    ['cswh'] = 'Contextual Swash',
    ['curs'] = 'Cursive Positioning',
    ['dflt'] = 'Default Processing',
    ['dist'] = 'Distances',
    ['dlig'] = 'Discretionary Ligatures',
    ['dnom'] = 'Denominators',
    ['expt'] = 'Expert Forms',
    ['falt'] = 'Final glyph Alternates',
    ['fin2'] = 'Terminal Forms #2',
    ['fin3'] = 'Terminal Forms #3',
    ['fina'] = 'Terminal Forms',
    ['frac'] = 'Fractions',
    ['fwid'] = 'Full Width',
    ['half'] = 'Half Forms',
    ['haln'] = 'Halant Forms',
    ['halt'] = 'Alternate Half Width',
    ['hist'] = 'Historical Forms',
    ['hkna'] = 'Horizontal Kana Alternates',
    ['hlig'] = 'Historical Ligatures',
    ['hngl'] = 'Hangul',
    ['hojo'] = 'Hojo Kanji Forms',
    ['hwid'] = 'Half Width',
    ['init'] = 'Initial Forms',
    ['isol'] = 'Isolated Forms',
    ['ital'] = 'Italics',
    ['jalt'] = 'Justification Alternatives',
    ['jp04'] = 'JIS2004 Forms',
    ['jp78'] = 'JIS78 Forms',
    ['jp83'] = 'JIS83 Forms',
    ['jp90'] = 'JIS90 Forms',
    ['kern'] = 'Kerning',
    ['lfbd'] = 'Left Bounds',
    ['liga'] = 'Standard Ligatures',
    ['ljmo'] = 'Leading Jamo Forms',
    ['lnum'] = 'Lining Figures',
    ['locl'] = 'Localized Forms',
    ['mark'] = 'Mark Positioning',
    ['med2'] = 'Medial Forms #2',
    ['medi'] = 'Medial Forms',
    ['mgrk'] = 'Mathematical Greek',
    ['mkmk'] = 'Mark to Mark Positioning',
    ['mset'] = 'Mark Positioning via Substitution',
    ['nalt'] = 'Alternate Annotation Forms',
    ['nlck'] = 'NLC Kanji Forms',
    ['nukt'] = 'Nukta Forms',
    ['numr'] = 'Numerators',
    ['onum'] = 'Old Style Figures',
    ['opbd'] = 'Optical Bounds',
    ['ordn'] = 'Ordinals',
    ['ornm'] = 'Ornaments',
    ['palt'] = 'Proportional Alternate Width',
    ['pcap'] = 'Petite Capitals',
    ['pnum'] = 'Proportional Figures',
    ['pref'] = 'Pre-base Forms',
    ['pres'] = 'Pre-base Substitutions',
    ['pstf'] = 'Post-base Forms',
    ['psts'] = 'Post-base Substitutions',
    ['pwid'] = 'Proportional Widths',
    ['qwid'] = 'Quarter Widths',
    ['rand'] = 'Randomize',
    ['rkrf'] = 'Rakar Forms',
    ['rlig'] = 'Required Ligatures',
    ['rphf'] = 'Reph Form',
    ['rtbd'] = 'Right Bounds',
    ['rtla'] = 'Right-To-Left Alternates',
    ['ruby'] = 'Ruby Notation Forms',
    ['salt'] = 'Stylistic Alternates',
    ['sinf'] = 'Scientific Inferiors',
    ['size'] = 'Optical Size',
    ['smcp'] = 'Small Capitals',
    ['smpl'] = 'Simplified Forms',
    ['ss01'] = 'Stylistic Set 1',
    ['ss02'] = 'Stylistic Set 2',
    ['ss03'] = 'Stylistic Set 3',
    ['ss04'] = 'Stylistic Set 4',
    ['ss05'] = 'Stylistic Set 5',
    ['ss06'] = 'Stylistic Set 6',
    ['ss07'] = 'Stylistic Set 7',
    ['ss08'] = 'Stylistic Set 8',
    ['ss09'] = 'Stylistic Set 9',
    ['ss10'] = 'Stylistic Set 10',
    ['ss11'] = 'Stylistic Set 11',
    ['ss12'] = 'Stylistic Set 12',
    ['ss13'] = 'Stylistic Set 13',
    ['ss14'] = 'Stylistic Set 14',
    ['ss15'] = 'Stylistic Set 15',
    ['ss16'] = 'Stylistic Set 16',
    ['ss17'] = 'Stylistic Set 17',
    ['ss18'] = 'Stylistic Set 18',
    ['ss19'] = 'Stylistic Set 19',
    ['ss20'] = 'Stylistic Set 20',
    ['subs'] = 'Subscript',
    ['sups'] = 'Superscript',
    ['swsh'] = 'Swash',
    ['titl'] = 'Titling',
    ['tjmo'] = 'Trailing Jamo Forms',
    ['tnam'] = 'Traditional Name Forms',
    ['tnum'] = 'Tabular Figures',
    ['trad'] = 'Traditional Forms',
    ['twid'] = 'Third Widths',
    ['unic'] = 'Unicase',
    ['valt'] = 'Alternate Vertical Metrics',
    ['vatu'] = 'Vattu Variants',
    ['vert'] = 'Vertical Writing',
    ['vhal'] = 'Alternate Vertical Half Metrics',
    ['vjmo'] = 'Vowel Jamo Forms',
    ['vkna'] = 'Vertical Kana Alternates',
    ['vkrn'] = 'Vertical Kerning',
    ['vpal'] = 'Proportional Alternate Vertical Metrics',
    ['vrt2'] = 'Vertical Rotation',
    ['zero'] = 'Slashed Zero'
}

fonts.otf.tables.baselines = {
    ['hang'] = 'Hanging baseline',
    ['icfb'] = 'Ideographic character face bottom edge baseline',
    ['icft'] = 'Ideographic character face tope edige baseline',
    ['ideo'] = 'Ideographic em-box bottom edge baseline',
    ['idtp'] = 'Ideographic em-box top edge baseline',
    ['math'] = 'Mathmatical centered baseline',
    ['romn'] = 'Roman baseline'
}

function fonts.otf.tables.to_tag(id)
    return stringformat("%4s",id:lower())
end

function fonts.otf.meanings.resolve(tab,id)
    if tab and id then
        id = id:lower()
        return tab[id] or tab[id:gsub(" ","")] or tab['dflt'] or ''
    else
        return "unknown"
    end
end

function fonts.otf.meanings.script(id)
    return fonts.otf.meanings.resolve(fonts.otf.tables.scripts,id)
end
function fonts.otf.meanings.language(id)
    return fonts.otf.meanings.resolve(fonts.otf.tables.languages,id)
end
function fonts.otf.meanings.feature(id)
    return fonts.otf.meanings.resolve(fonts.otf.tables.features,id)
end
function fonts.otf.meanings.baseline(id)
    return fonts.otf.meanings.resolve(fonts.otf.tables.baselines,id)
end

function table.reverse_hash(h)
    local r = { }
    for k,v in pairs(h) do
        r[v] = (k:gsub(" ","")):lower()
    end
    return r
end

fonts.otf.tables.to_scripts   = table.reverse_hash(fonts.otf.tables.scripts  )
fonts.otf.tables.to_languages = table.reverse_hash(fonts.otf.tables.languages)
fonts.otf.tables.to_features  = table.reverse_hash(fonts.otf.tables.features )

do

    local scripts      = fonts.otf.tables.scripts
    local languages    = fonts.otf.tables.languages
    local features     = fonts.otf.tables.features

    local to_scripts   = fonts.otf.tables.to_scripts
    local to_languages = fonts.otf.tables.to_languages
    local to_features  = fonts.otf.tables.to_features

    function fonts.otf.meanings.normalize(features)
        local h = { }
        for k,v in pairs(features) do
            k = (k:lower()):gsub("[^a-z0-9%-]","")
            if k == "language" or k == "lang" then
                v = (v:lower()):gsub("[^a-z0-9%-]","")
                k = language
                if not languages[v] then
                    h.language = to_languages[v] or "dflt"
                else
                    h.language = v
                end
            elseif k == "script" then
                v = (v:lower()):gsub("[^a-z0-9%-]","")
                if not scripts[v] then
                    h.script = to_scripts[v] or "dflt"
                else
                    h.script = v
                end
            else
                if type(v) == "string" then
                    local b = v:is_boolean()
                    if type(b) == "nil" then
                        v = (v:lower()):gsub("[^a-z0-9%-]","")
                    else
                        v = b
                    end
                end
                h[to_features[k] or k] = v
            end
        end
        return h
    end

end

--[[ldx--
<p>Here we go.</p>
--ldx]]--

fonts.otf.enhance           = fonts.otf.enhance or { }
fonts.otf.enhance.add_kerns = true

fonts.otf.featurefiles = {
--~     "texhistoric.fea"
}

function fonts.otf.load(filename,format,sub,featurefile)
    local name = file.basename(file.removesuffix(filename))
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    if sub == "" then sub = false end
    local hash = name
    if sub then -- name cleanup will move to cache code
        hash = hash .. "-" .. sub
        hash = hash:lower()
        hash = hash:gsub("[^%w%d]+","-")
    end
    local data = containers.read(fonts.otf.cache, hash)
    local size = lfs.attributes(filename,"size") or 0
    if data and data.size ~= size then
        data = nil
    end
    if not data then
        logs.report("load otf","loading: " .. filename)
        local ff, messages
        if sub then
            ff, messages = fontforge.open(filename,sub)
        else
            ff, messages = fontforge.open(filename)
        end
        if messages and #messages > 0 then
            for _, m in ipairs(messages) do
                logs.report("load otf","warning: " .. m)
            end
        end
        if ff then
            local function load_featurefile(featurefile)
                if featurefile then
                    featurefile = input.find_file(texmf.instance,file.addsuffix(featurefile,'fea'),"FONTFEATURES")
                    if featurefile and featurefile ~= "" then
                        logs.report("load otf", "featurefile: " .. featurefile)
                        fontforge.apply_featurefile(ff, featurefile)
                    end
                end
            end
        --  for _, featurefile in pairs(fonts.otf.featurefiles) do
        --      load_featurefile(featurefile)
        --  end
            load_featurefile(featurefile)
            data = fontforge.to_table(ff)
            fontforge.close(ff)
            if data then
                logs.report("load otf","enhance: before")
                fonts.otf.enhance.before(data,filename)
                logs.report("load otf","enhance: enrich")
                fonts.otf.enhance.enrich(data,filename)
                logs.report("load otf","enhance: flatten")
                fonts.otf.enhance.flatten(data,filename)
                logs.report("load otf","enhance: analyze")
                fonts.otf.enhance.analyze(data,filename)
                logs.report("load otf","enhance: after")
                fonts.otf.enhance.after(data,filename)
                logs.report("load otf","enhance: patch")
                fonts.otf.enhance.patch(data,filename)
                logs.report("load otf","enhance: strip")
                fonts.otf.enhance.strip(data,filename)
                if fonts.otf.pack then
                    logs.report("load otf","enhance: pack")
                    fonts.otf.enhance.pack(data)
                end
                logs.report("load otf","file size: " .. size)
                data.size = size
                logs.report("load otf","saving: in cache")
                data = containers.write(fonts.otf.cache, hash, data)
            else
                logs.error("load otf","loading failed (table conversion error)")
            end
        else
            logs.error("load otf","loading failed (file read error)")
        end
    end
    fonts.otf.enhance.unpack(data)
    return data
end

-- memory saver ..

function fonts.otf.enhance.pack(data)
    if data then
        local h, t = { }, { }
        local concat = table.concat
        local function tabstr(t)
            for i=1,#t do
                if type(t[i]) == "boolean" then
                    local s = tostring(t[1])
                    for i=2,#t do
                        s = s .. ",".. tostring(t[i])
                    end
                    return s
                end
            end
            return concat(t,",")
        end
        local function pack(v)
            local tag = tabstr(v,",")
            if not h[tag] then
                t[#t+1] = v
                h[tag] = #t
            end
            return h[tag]
        end
        for k, v in pairs(data.glyphs) do
            v.boundingbox = pack(v.boundingbox)
            if v.lookups then
                for k,v in pairs(v.lookups) do
                    for kk, vv in ipairs(v) do
                        v[kk] = pack(vv)
                    end
                end
            end
        end
        if data.lookups then
            for k, v in pairs(data.lookups) do
                if v.rules then
                    for kk, vv in pairs(v.rules) do
                        local l = vv.lookups
                        if l then
                            vv.lookups = pack(l)
                        end
                        local c = vv.coverage
                        if c then
                            c.before  = c.before  and pack(c.before )
                            c.after   = c.after   and pack(c.after  )
                            c.current = c.current and pack(c.current)
                        end
                    end
                end
            end
        end
        if data.luatex then
            local li = data.luatex.ignore_flags
            if li then
                for k, v in pairs(li) do
                    li[k] = pack(v)
                end
            end
        end
        if #t > 0 then
            data.tables = t
        end
    end
end

function fonts.otf.enhance.unpack(data)
    if data then
        local t = data.tables
        if t then
            for k, v in pairs(data.glyphs) do
                v.boundingbox = t[v.boundingbox]
                local l = v.lookups
                if l then
                    for k,v in pairs(l) do
                        for i=1,#v do
                            v[i] = t[v[i]]
                        end
                    end
                end
            end
            if data.lookups then
                for k, v in pairs(data.lookups) do
                    local r = v.rules
                    if r then
                        for kk, vv in pairs(r) do
                            local l = vv.lookups
                            if l then
                                vv.lookups = t[l]
                            end
                            local c = vv.coverage
                            if c then
                                if c.before  then c.before  = t[c.before]  end
                                if c.after   then c.after   = t[c.after]   end
                                if c.current then c.current = t[c.current] end
                            end
                        end
                    end
                end
            end
            if data.luatex then
                local li = data.luatex.ignore_flags
                if li then
                    for k, v in pairs(li) do
                        li[k] = t[v]
                    end
                end
            end
            data.tables = nil
        end
    end
end

-- todo: normalize, design_size => designsize

function fonts.otf.enhance.analyze(data,filename)
    local t = {
        filename = file.basename(filename),
        version  = fonts.otf.version,
        creator  = "context mkiv",
        unicodes = fonts.otf.analyze_unicodes(data),
        gposfeatures = fonts.otf.analyze_features(data.gpos),
        gsubfeatures = fonts.otf.analyze_features(data.gsub),
        marks = fonts.otf.analyze_class(data,'mark'),
    }
    t.subtables, t.name_to_type, t.internals, t.always_valid, t.ignore_flags, t.ctx_always = fonts.otf.analyze_subtables(data)
    data.luatex = t
end

do
    -- original string parsr: 0.109, lpeg parser: 0.036 seconds for Adobe-CNS1-4.cidmap
    --
    -- 18964 18964 (leader)
    -- 0 /.notdef
    -- 1..95 0020
    -- 99 3000

    local number  = lpeg.C(lpeg.R("09","af","AF")^1)
    local space   = lpeg.S(" \n\r\t")
    local spaces  = space^0
    local period  = lpeg.P(".")
    local periods = period * period
    local name    = lpeg.P("/") * lpeg.C((1-space)^1)

    local unicodes, names = { }, {}

    local tonumber = tonumber

    function do_one(a,b)
        unicodes[tonumber(a)] = tonumber(b,16)
    end
    function do_range(a,b,c)
        c = tonumber(c,16)
        for i=tonumber(a),tonumber(b) do
            unicodes[i] = c
            c = c + 1
        end
    end
    function do_name(a,b)
        names[tonumber(a)] = b
    end

    grammar = lpeg.P { "start",
        start  = number * spaces * number * lpeg.V("series"),
        series = (spaces * (lpeg.V("one") + lpeg.V("range") + lpeg.V("named")) )^1,
        one    = (number * spaces  * number) / do_one,
        range  = (number * periods * number * spaces * number) / do_range,
        named  = (number * spaces  * name) / do_name
    }

    function fonts.otf.load_cidmap(filename) -- lpeg
        local data = io.loaddata(filename)
        if data then
            unicodes, names = { }, { }
            grammar:match(data)
            local supplement, registry, ordering = filename:match("^(.-)%-(.-)%-()%.(.-)$")
            return {
                supplement = supplement,
                registry   = registry,
                ordering   = ordering,
                filename   = filename,
                unicodes   = unicodes,
                names      = names
            }
        else
            return nil
        end
    end

end

fonts.otf.cidmaps = { }

--~ function fonts.otf.cidmap(registry,ordering,supplement)
--~     local template = "%s-%s-%s.cidmap"
--~     local filename = string.format(template,registry,ordering,supplement)
--~     local supplement = tonumber(supplement)
--~     local cidmap = fonts.otf.cidmaps[filename]
--~     if not cidmap then
--~         for i=supplement,0,-1 do
--~             logs.report("load otf",string.format("checking cidmap, registry: %s, ordering: %s, supplement: %s",registry,ordering,i))
--~             filename = string.format(template,registry,ordering,i)
--~             local fullname = input.find_file(texmf.instance,filename,'cid') or ""
--~             if fullname ~= "" then
--~                 cidmap = fonts.otf.load_cidmap(fullname)
--~                 if cidmap then
--~                     logs.report("load otf",string.format("using cidmap file %s",filename))
--~                     fonts.otf.cidmaps[filename] = cidmap
--~                     if i < supplement then
--~                         for j=i+1,supplement do
--~                             filename = string.format(template,registry,ordering,j)
--~                             fonts.otf.cidmaps[filename] = cidmap -- copy of ref
--~                         end
--~                     end
--~                     return cidmap
--~                 end
--~             end
--~         end
--~     end
--~     return cidmap
--~ end

fonts.otf.cidmax = 10

function fonts.otf.cidmap(registry,ordering,supplement)
    -- cf Arthur R. we can safely scan upwards since cids are downward compatible
    local template = "%s-%s-%s.cidmap"
    local supplement = tonumber(supplement)
    logs.report("load otf",string.format("needed cidmap, registry: %s, ordering: %s, supplement: %s",registry,ordering,supplement))
    local function locate(registry,ordering,supplement)
        local filename = string.format(template,registry,ordering,supplement)
        local cidmap = fonts.otf.cidmaps[filename]
        if not cidmap then
            logs.report("load otf",string.format("checking cidmap, registry: %s, ordering: %s, supplement: %s, filename: %s",registry,ordering,supplement,filename))
            local fullname = input.find_file(texmf.instance,filename,'cid') or ""
            if fullname ~= "" then
                cidmap = fonts.otf.load_cidmap(fullname)
                if cidmap then
                    logs.report("load otf",string.format("using cidmap file %s",filename))
                    fonts.otf.cidmaps[filename] = cidmap
                    return cidmap
                end
            end
        end
        return cidmap
    end
    local cidmap = locate(registry,ordering,supplement)
    if not cidmap then
        local cidnum = nil
        -- next highest (alternatively we could start high)
        if supplement < fonts.otf.cidmax then
            for supplement=supplement+1,fonts.otf.cidmax do
                local c = locate(registry,ordering,supplement)
                if c then
                    cidmap, cidnum = c, supplement
                    break
                end
            end
        end
        -- next lowest (least worse fit)
        if not cidmap and supplement > 0 then
            for supplement=supplement-1,0,-1 do
                local c = locate(registry,ordering,supplement)
                if c then
                    cidmap, cidnum = c, supplement
                    break
                end
            end
        end
        -- prevent further lookups
        if cidmap and cidnum > 0 then
            for s=0,cidnum-1 do
                filename = string.format(template,registry,ordering,s)
                if not fonts.otf.cidmaps[filename] then
                    fonts.otf.cidmaps[filename] = cidmap -- copy of ref
                end
            end
        end
    end
    return cidmap
end

--~  ["cidinfo"]={
--~   ["ordering"]="Japan1",
--~   ["registry"]="Adobe",
--~   ["supplement"]=6,
--~   ["version"]=6,
--~  },

function fonts.otf.enhance.before(data,filename)
    local private = 0xE000
    if data.subfonts and table.is_empty(data.glyphs) then
        local cidinfo = data.cidinfo
        if cidinfo.registry then
            local cidmap = fonts.otf.cidmap(cidinfo.registry,cidinfo.ordering,cidinfo.supplement)
            if cidmap then
                local glyphs, uni_to_int, int_to_uni, nofnames, nofunicodes = { }, { }, { }, 0, 0
                local unicodes, names = cidmap.unicodes, cidmap.names
                for n, subfont in pairs(data.subfonts) do
                    for index, g in pairs(subfont.glyphs) do
                        if not next(g) then
                            -- dummy entry
                        else
                            local unicode, name = unicodes[index], names[index]
                            g.cidindex = n
                            g.boundingbox = g.boundingbox -- or zerobox
                            g.name = g.name or name or "unknown"
                            if unicode then
                                g.unicode = unicode
                                uni_to_int[unicode] = index
                                int_to_uni[index] = unicode
                                nofunicodes = nofunicodes + 1
                            elseif name then
                                g.unicode = -1
                                nofnames = nofnames + 1
                            end
                            glyphs[index] = g
                        end
                    end
                    subfont.glyphs = nil
                end
                logs.report("load otf",string.format("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes, nofnames, nofunicodes+nofnames))
                data.glyphs = glyphs
                data.map = data.map or { }
                data.map.map = uni_to_int
                data.map.backmap = int_to_uni
            else
                logs.report("load otf",string.format("unable to remap cid font, missing cid file for %s",filename))
            end
        else
            logs.report("load otf",string.format("font %s has no glyphs",filename))
        end
    end
    if data.map then
        local uni_to_int = data.map.map
        local int_to_uni = data.map.backmap
        for index, glyph in pairs(data.glyphs) do
            if glyph.name then
                local unic = glyph.unicode or glyph.unicodeenc or -1
                glyph.unicodeenc = nil -- older luatex version
                if index > 0 and (unic == -1 or unic >= 0x110000) then
                    while uni_to_int[private] do
                        private = private + 1
                    end
                    uni_to_int[private] = index
                    int_to_uni[index] = private
                    glyph.unicode = private
                    if fonts.trace then
                        logs.report("load otf",string.format("enhance: glyph %s at index %s is moved to private unicode slot %s",glyph.name,index,private))
                    end
                else
                    glyph.unicode = unic -- safeguard for older version
                end
            end
        end
        local n = 0
        for k,v in pairs(int_to_uni) do
            if v == -1 or v >= 0x110000 then
                int_to_uni[k], n = nil, n+1
            end
        end
        if fonts.trace then
            logs.report("load otf",string.format("enhance: %s entries removed from map.backmap",n))
        end
        local n = 0
        for k,v in pairs(uni_to_int) do
            if k == -1 or k >= 0x110000 then
                uni_to_int[k], n = nil, n+1
            end
        end
        if fonts.trace then
            logs.report("load otf",string.format("enhance: %s entries removed from map.mapmap",n))
        end
    else
        data.map = { map = {}, backmap = {} }
    end
    if data.ttf_tables then
        for _, v in ipairs(data.ttf_tables) do
            if v.data then v.data = "deleted" end
        --~ if v.data then v.data = v.data:gsub("\026","\\026") end -- does not work out well
        end
    end
    table.compact(data.glyphs)
    if data.subfonts then
        for _, subfont in pairs(data.subfonts) do
            table.compact(subfont.glyphs)
        end
    end

--~ for index, glyph in pairs(data.glyphs) do
--~     for k,v in pairs(glyph) do
--~         if v == 0 then glyph[k] = nil end
--~     end
--~ end

end

function fonts.otf.enhance.after(data,filename) -- to be split
    if fonts.otf.enhance.add_kerns then
        local glyphs, mapmap, unicodes = data.glyphs, data.map.map, data.luatex.unicodes
        local mkdone = false
        for index, glyph in pairs(data.glyphs) do
            if glyph.kerns then
                local mykerns = { } -- unicode indexed !
                for k,v in pairs(glyph.kerns) do
                    local vc, vo, vl = v.char, v.off, v.lookup
                    if vc and vo and vl then -- brrr, wrong! we miss the non unicode ones
                        local uvc = unicodes[vc]
                        if uvc then
                            local mkl = mykerns[vl]
                            if not mkl then
                                mkl = { [unicodes[vc]] = vo }
                                mykerns[v.lookup] = mkl
                            else
                                mkl[unicodes[vc]] = vo
                            end
                        else
                            logs.report("load otf", string.format("problems with unicode %s of kern %s at glyph %s",vc,k,index))
                        end
                    end
                end
                glyph.mykerns = mykerns
                glyph.kerns = nil -- saves space and time
                mkdone = true
            end
        end
        if mkdone then
            logs.report("load otf", "replacing 'kerns' tables by 'mykerns' tables")
        end
        if data.gpos then
            for _, gpos in ipairs(data.gpos) do
                if gpos.subtables then
                    for _, subtable in ipairs(gpos.subtables) do
                        local kernclass = subtable.kernclass
                        if kernclass then
                            for _, kcl in ipairs(kernclass) do
                                local firsts, seconds, offsets, lookup = kcl.firsts, kcl.seconds, kcl.offsets, kcl.lookup
                                local maxfirsts, maxseconds = table.getn(firsts), table.getn(seconds)
                                logs.report("load otf", string.format("adding kernclass %s with %s times %s pairs)",lookup, maxfirsts, maxseconds))
                                for fk, fv in pairs(firsts) do
                                    for first in fv:gmatch("[^ ]+") do
                                        local glyph = glyphs[mapmap[unicodes[first]]]
                                        local mykerns = glyph.mykerns
                                        if not mykerns then
                                            mykerns = { } -- unicode indexed !
                                            glyph.mykerns = mykerns
                                        end
                                        local lookupkerns = mykerns[lookup]
                                        if not lookupkerns then
                                            lookupkerns = { }
                                            mykerns[lookup] = lookupkerns
                                        end
                                        for sk, sv in pairs(seconds) do
                                            for second in sv:gmatch("[^ ]+") do
                                                lookupkerns[unicodes[second]] = offsets[(fk-1) * maxseconds + sk]
                                            end
                                        end
                                    end
                                end
                            end
                            subtable.comment = "The kernclass table is merged into mykerns in the indexed glyph tables."
                            subtable.kernclass = { }
                        end
                    end
                end
            end
        end
    end
end

function fonts.otf.enhance.strip(data)
--~     if data.map then
--~         data.map.enc = nil -- not needed
--~     end
--~     data.map = { map = {}, backmap = {} }
    for k, v in pairs(data.glyphs) do
        local d = v.dependents
        if d then v.dependents = nil end
    end
    data.map = nil
    data.names = nil
    data.luatex.comment = "Glyph tables have their original index. When present, mykern tables are indexed by unicode."
end

function fonts.otf.enhance.flatten(data,filename) -- to be split
    logs.report("load otf", "flattening 'specifications' tables")
    for k, v in pairs(data.glyphs) do
        if v.lookups then
            for kk, vv in pairs(v.lookups) do
                for kkk, vvv in ipairs(vv) do
                    local s = vvv.specification
                    if s then
                        local t = vvv.type
                        if t == "ligature" then
                            vv[kkk] = { "ligature", s.components, s.char }
                        elseif t == "alternate" then
                            vv[kkk] = { "alternate", s.components }
                        elseif t == "substitution" then
                            vv[kkk] = { "substitution", s.variant }
                        elseif t == "multiple" then
                            vv[kkk] = { "multiple", s.components }
                        elseif t == "position" then
                            vv[kkk] = { "position", s.x or 0, s.y or 0, s.h or 0, s.v or 0 }
                        elseif t == "pair" then
                            local one, two, paired = s.offsets[1], s.offsets[2], s.paired or ""
                            if one then
                                if two then
                                    vv[kkk] = { "pair", paired, one.x or 0, one.y or 0, one.h or 0, one.v or 0, two.x or 0, two.y or 0, two.h or 0, two.v or 0 }
                                else
                                    vv[kkk] = { "pair", paired, one.x or 0, one.y or 0, one.h or 0 }
                                end
                            else
                                if two then
                                    vv[kkk] = { "pair", paired, 0, 0, 0, 0, two.x or 0, two.y or 0, two.h or 0, two.v or 0 }
                                else
                                    vv[kkk] = { "pair", paired }
                                end
                            end
                        else
                            logs.report("load otf", "flattening needed, warn Hans and/or Taco")
                            for a, b in pairs(s) do
                                if vvv[a] then
                                    logs.report("load otf", "flattening conflict, warn Hans and/or Taco")
                                end
                                vvv[a] = b
                            end
                            vvv.specification = nil
                        end
                    end
                end
            end
        end
    end
    logs.report("load otf", "flattening 'anchor' tables")
    for k, v in pairs(data.glyphs) do
        if v.anchors then
            for kk, vv in pairs(v.anchors) do
                for kkk, vvv in pairs(vv) do
                    if vvv.x or vvv.y then -- kkk == "centry"
                        vv[kkk] = { vvv.x or 0, vvv.y or 0 }
                    else
                        for kkkk, vvvv in ipairs(vvv) do
                            vvv[kkkk] = { vvvv.x or 0, vvvv.y or 0 }
                        end
                    end
                end
            end
        end
    end
    for _, tag in pairs({"gpos","gsub"}) do
        if data[tag] then
            logs.report("load otf", "flattening '" .. tag.. "' tables")
            for k, v in pairs(data[tag]) do
                if v.features then
                    for kk, vv in ipairs(v.features) do
                        local t = { }
                        for kkk, vvv in ipairs(vv.scripts) do
                            t[vvv.script] = vvv.langs
                        end
                        vv.scripts = t
                    end
                end
            end
        end
    end
end

fonts.otf.enhance.patches = { }

function fonts.otf.enhance.patch(data,filename)
    local basename = file.basename(filename)
    for pattern, action in pairs(fonts.otf.enhance.patches) do
        if basename:find(pattern) then
            action(data,filename)
        end
    end
end

-- tex features

function fonts.otf.enhance.enrich(data,filename)
    -- later
end

-- patching

do -- will move to a typescript

    local function patch(data,filename)
        if data.design_size == 0 then
            local ds = (file.basename(filename)):match("(%d+)")
            if ds then
                logs.report("load otf",string.format("patching design size (%s)",ds))
                data.design_size = tonumber(ds) * 10
            end
        end
    end

    fonts.otf.enhance.patches["^lmroman"]      = patch
    fonts.otf.enhance.patches["^lmsans"]       = patch
    fonts.otf.enhance.patches["^lmtypewriter"] = patch

end

function fonts.otf.analyze_class(data,class)
    local classes = { }
    for index, glyph in pairs(data.glyphs) do
        if glyph.class == class then
            classes[glyph.unicode] = true
        end
    end
    return classes
end

function fonts.otf.analyze_subtables(data)
    local subtables, name_to_type, internals, always_valid, ignore_flags, ctx_always = { }, { }, { }, { }, { }, { }
    local function collect(g)
        if g then
            for k,v in ipairs(g) do
                if v.features then
                    local ignored = { false, false, false }
                    if v.flags.ignorecombiningmarks then ignored[1] = 'mark'    end
                    if v.flags.ignorebasechars      then ignored[2] = 'base'     end
                    if v.flags.ignoreligatures      then ignored[3] = 'ligature' end
                    if v.subtables then
                        local type = v.type
                        for _, feature in ipairs(v.features) do
                            local ft = feature.tag:lower()
                            subtables[ft] = subtables[ft] or { }
                            ctx_always[ft] = v.always
                            for script, languages in pairs(feature.scripts) do
                                script = script:lower()
                                script = script:strip()
                                sft = subtables[ft]
                                sft[script] = sft[script] or { }
                                local sfts = sft[script]
                                for _, language in ipairs(languages) do
                                    language = language:lower()
                                    language = language:strip()
                                    sfts[language] = sfts[language] or { }
                                    local sftsl = sfts[language]
                                    local lookups, valid = sftsl.lookups or { }, sftsl.valid or { }
                                    for n, subtable in ipairs(v.subtables) do
                                        local stl = subtable.name
                                        if stl then
                                            lookups[#lookups+1] = stl
                                            valid[stl] = true
                                            name_to_type[stl] = type
                                            ignore_flags[stl] = ignored
                                        end
                                    end
                                    sftsl.lookups, sftsl.valid = lookups, valid
                                end
                            end
                        end
                    end
                else
                    -- we have an internal feature, say ss_l_83 that resolves to
                    -- subfeatures like ss_l_83_s which we find in the glyphs
                    name_to_type[v.name] = v.type
                    local lookups, valid = { }, { }
                    for n, subtable in ipairs(v.subtables) do
                        local stl = subtable.name
                        if stl then
                            lookups[#lookups+1] = stl
                            valid[stl] = true
                            always_valid[stl] = true
                        end
                    end
                    internals[v.name] = {
                        lookups = lookups,
                        valid = valid
                    }
                    always_valid[v.name] = true -- bonus
                end
            end
        end
    end
    collect(data.gsub)
    collect(data.gpos)
    return subtables, name_to_type, internals, always_valid, ignore_flags, ctx_always
end

function fonts.otf.analyze_unicodes(data)
    local unicodes = { }
    for _, blob in pairs(data.glyphs) do
        if blob.name then
            unicodes[blob.name] = blob.unicode or 0
        end
    end
    unicodes['space'] = unicodes['space'] or 32 -- handly later on
    return unicodes
end

function fonts.otf.analyze_features(g, features)
    if g then
        local t, done = { }, { }
        for k=1,#g do
            local f = features or g[k].features
            if f then
                for k=1,#f do
                    -- scripts and tag
                    local tag = f[k].tag
                    if not done[tag] then
                        t[#t+1] = tag
                        done[tag] = true
                    end
                end
            end
        end
        if #t > 0 then
            return t
        end
    end
    return nil
end

function fonts.otf.valid_subtable(otfdata,kind,script,language)
    local tk = otfdata.luatex.subtables[kind]
    if tk then
        local tks = tk[script] or tk.dflt
        if tks then
            local tksl = tks[language] or tks.dflt
            if tksl then
                return tksl.lookups
            end
        end
    end
    return false
end

function fonts.otf.features.register(name,default)
    fonts.otf.features.list[#fonts.otf.features.list+1] = name
    fonts.otf.features.default[name] = default
end

function fonts.otf.set_features(tfmdata) -- node and base, simple mapping
    local shared = tfmdata.shared
    local otfdata = shared.otfdata
    shared.features = fonts.define.check(shared.features,fonts.otf.features.default)
    local features = shared.features
    local trace = fonts.otf.trace_features or fonts.otf.trace_set_features
    if not tfmdata.language then tfmdata.language = 'dflt' end
    if not tfmdata.script   then tfmdata.script   = 'dflt' end
    if not table.is_empty(features) then
        local gposlist = otfdata.luatex.gposfeatures
        local gsublist = otfdata.luatex.gsubfeatures
        local mode = tfmdata.mode or fonts.mode
        local fi = fonts.initializers[mode]
        if fi then -- todo: delay initilization for mode 'node'
            local fiotf = fi.otf
            if fiotf then
                local done = { }
                local function initialize(list) -- using tex lig and kerning
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            local value = features[f]
                            if value and fiotf[f] then -- brr
                                if not done[f] then -- so, we can move some to triggers
                                    if trace then
                                        logs.report("define otf",string.format("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown', tfmdata.fullname or 'unknown'))
                                    end
                                    fiotf[f](tfmdata,value) -- can set mode (no need to pass otf)
                                    mode = tfmdata.mode or fonts.mode -- keep this, mode can be set local !
                                    local fi = fonts.initializers[mode]
                                    fiotf = fi.otf
                                    done[f] = true
                                end
                            end
                        end
                    end
                end
                initialize(fonts.triggers)
                initialize(gsublist)
                initialize(gposlist)
                initialize(fonts.manipulators)
            end
        end
        local fm = fonts.methods[mode]
        if fm then
            local fmotf = fm.otf
            local sp = shared.processors
            if fmotf then
                local function register(list) -- node manipulations
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            if features[f] and fmotf[f] then -- brr
                                if trace then
                                    logs.report("define otf",string.format("installing feature handler %s for mode %s for font %s",f,mode or 'unknown', tfmdata.fullname or 'unknown'))
                                end
                                sp[#sp+1] = fmotf[f]
                            end
                        end
                    end
                end
                register(fonts.triggers)
                register(gsublist)
                register(gposlist)
                register(fonts.manipulators)
            end
        end
    end
end

function fonts.otf.otf_to_tfm(specification)
    local name     = specification.name
    local sub      = specification.sub
    local filename = specification.filename
    local format   = specification.format
    local features = specification.features.normal
    local cache_id = specification.hash
    local tfmdata  = containers.read(fonts.tfm.cache,cache_id)
    if not tfmdata then
        local otfdata = fonts.otf.load(filename,format,sub,features and features.featurefile)
        if not table.is_empty(otfdata) then
            fonts.otf.add_dimensions(otfdata)
            if true then
                otfdata._shared_ = otfdata._shared_ or { -- aggressive sharing
                    processes    = { },
                    lookuptable  = { },
                    featuredata  = { },
                    featurecache = { },
                }
            end
            tfmdata = fonts.otf.copy_to_tfm(otfdata)
            if not table.is_empty(tfmdata) then
                tfmdata.unique = tfmdata.unique or { }
                tfmdata.shared = tfmdata.shared or { } -- combine
                local shared = tfmdata.shared
                shared.otfdata = otfdata
                shared.features = features
                shared.processors = { }
                shared.dynamics = { }
                shared.processes = { }
                shared.lookuptable = { }
                shared.featuredata = { }
                shared.featurecache = { }
                if otfdata._shared_ then
                    shared.processes    = otfdata._shared_.processes
                    shared.lookuptable  = otfdata._shared_.lookuptable
                    shared.featuredata  = otfdata._shared_.featuredata
                    shared.featurecache = otfdata._shared_.featurecache
                end
                fonts.otf.set_features(tfmdata)
            end
        end
        containers.write(fonts.tfm.cache,cache_id,tfmdata)
    end
    return tfmdata
end

function fonts.otf.features.prepare_base_kerns(tfmdata,kind,value) -- todo what kind of kerns, currently all
    if value then
        local otfdata = tfmdata.shared.otfdata
        local charlist = otfdata.glyphs
        local unicodes = otfdata.luatex.unicodes
        local somevalid = fonts.otf.some_valid_feature(otfdata,kind,tfmdata.script,tfmdata.language)
        for _, chr in pairs(tfmdata.characters) do
            local d = charlist[chr.description.index]
            if d then
                local dk = d.mykerns
                if dk then
                    local t, done = chr.kerns or { }, false
                    for lookup,kerns in pairs(dk) do
                        if somevalid[lookup] then
                            for k, v in pairs(kerns) do
                                if v > 0 then
                                    t[k], done = v, true
                                end
                            end
                        end
                    end
                    if done then
                        chr.kerns = t -- no empty assignments
                    end
                else
                    dk = d.kerns
                    if dk then
                        local t, done = chr.kerns or { }, false
                        for _, v in pairs(dk) do
                            if somevalid[v.lookup] then
                                local k = unicodes[v.char]
                                if k > 0 then
                                    t[k], done = v.off, true
                                end
                            end
                        end
                        if done then
                            chr.kerns = t -- no empty assignments
                        end
                    end
                end
            end
        end
    end
end

function fonts.otf.add_dimensions(data)
    if data then
        local force = fonts.otf.notdef
        for k, d in pairs(data.glyphs) do
            local bb, wd = d.boundingbox, d.width or 0
            if force and not d.name then
                d.name = ".notdef"
            end
            if wd ~= 0 and d.class == "mark" then
                d.width  = -wd
            end
            if bb then
                local ht, dp = bb[4], -bb[2]
                if ht ~= 0 then d.height = ht end
                if dp ~= 0 then d.depth  = dp end
            end
            d.index  = k
        end
    end
end

function fonts.otf.copy_to_tfm(data) -- we can save a copy when we reorder the tma to unicode
    if data then
        local tfm = { characters = { }, parameters = { } }
        local unicodes = data.luatex.unicodes
        local characters = tfm.characters
        local parameters = tfm.parameters
        local glyphs = data.glyphs
        for k, d in pairs(glyphs) do
            if d.name then
                characters[d.unicode] = { description = d }
            end
        end
        local designsize = data.designsize or data.design_size or 100
        if designsize == 0 then
            designsize = 100
        end
        local spaceunits = 500
        tfm.units              = data.units_per_em or 1000
        -- we need a runtime lookup because of running from cdrom or zip, brrr
        tfm.filename           = input.findbinfile(texmf.instance,data.luatex.filename,"") or data.luatex.filename
        tfm.fullname           = data.fontname or data.fullname
        tfm.encodingbytes      = 2
        tfm.cidinfo            = data.cidinfo
        tfm.cidinfo.registry   = tfm.cidinfo.registry or ""
        tfm.type               = "real"
        tfm.stretch            = 0 -- stretch
        tfm.slant              = 0 -- slant
        tfm.direction          = 0
        tfm.boundarychar_label = 0
        tfm.boundarychar       = 65536
        tfm.designsize         = (designsize/10)*65536
        tfm.spacer             = "500 units"
        data.isfixedpitch      = data.pfminfo and data.pfminfo.panose and data.pfminfo.panose["proportion"] == "Monospaced"
        data.charwidth         = nil
        if data.pfminfo then
            data.charwidth = data.pfminfo.avgwidth
        end
        local endash, emdash = unicodes['space'], unicodes['emdash']
        if data.isfixedpitch then
            if characters[endash] then
                spaceunits, tfm.spacer = characters[endash].description.width, "space"
            end
            if not spaceunits and characters[emdash] then
                spaceunits, tfm.spacer = characters[emdash].description.width, "emdash"
            end
            if not spaceunits and data.charwidth then
                spaceunits, tfm.spacer = data.charwidth, "charwidth"
            end
        else
            if characters[endash] then
                spaceunits, tfm.spacer = characters[endash].description.width, "space"
            end
            if not spaceunits and characters[emdash] then
                spaceunits, tfm.spacer = characters[emdash].description.width/2, "emdash/2"
            end
            if not spaceunits and data.charwidth then
                spaceunits, tfm.spacer = data.charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits) or tfm.units/2 -- 500 -- brrr
        parameters[1] = 0                     -- slant
        parameters[2] = spaceunits            -- space
        parameters[3] = tfm.units/2   --  500 -- space_stretch
        parameters[4] = 2*tfm.units/3 --  333 -- space_shrink
        parameters[5] = 4*tfm.units/5 --  400 -- x_height
        parameters[6] = tfm.units     -- 1000 -- quad
        parameters[7] = 0                     -- extra_space (todo)
        if spaceunits < 2*tfm.units/5 then
            -- todo: warning
        end
        tfm.italicangle = data.italicangle
        tfm.ascender    = math.abs(data.ascent  or 0)
        tfm.descender   = math.abs(data.descent or 0)
        if data.italicangle then -- maybe also in afm _
           parameters[1] = parameters[1] - math.round(math.tan(data.italicangle*math.pi/180))
        end
        if data.isfixedpitch then
            parameters[3] = 0
            parameters[4] = 0
        elseif fonts.otf.syncspace then --
            parameters[3] = spaceunits/2  -- space_stretch
            parameters[4] = spaceunits/3  -- space_shrink
        end
        if data.pfminfo and data.pfminfo.os2_xheight and data.pfminfo.os2_xheight > 0 then
            parameters[5] = data.pfminfo.os2_xheight
        else
            local x = characters[unicodes['x']]
            if x then
                parameters[5] = x.description.height
            end
        end
        -- [6]
        return tfm
    else
        return nil
    end
end

function fonts.tfm.read_from_open_type(specification)
    local tfmtable = fonts.otf.otf_to_tfm(specification)
    if tfmtable then
        tfmtable.name = specification.name
        tfmtable.sub = specification.sub
        tfmtable = fonts.tfm.scale(tfmtable, specification.size)
     -- here we resolve the name; file can be relocated, so this info is not in the cache
        local otfdata = tfmtable.shared.otfdata
        local filename = (otfdata and otfdata.luatex and otfdata.luatex.filename) or specification.filename
        if not filename then
            -- try to locate anyway and set otfdata.luatex.filename
        end
        if filename then
            tfmtable.encodingbytes = 2
            tfmtable.filename = input.findbinfile(texmf.instance,filename,"") or filename
            tfmtable.fullname = otfdata.fontname or otfdata.fullname
            local order = otfdata and otfdata.order2
            if order == 0 then
                tfmtable.format = 'opentype'
            elseif order == 1 then
                tfmtable.format = 'truetype'
            else
                tfmtable.format = specification.format
            end
            tfmtable.name = tfmtable.filename or tfmtable.fullname
        end
        fonts.logger.save(tfmtable,file.extname(specification.filename),specification)
    end
    return tfmtable
end

function fonts.otf.analyze_only(otfdata)
    local analyze = fonts.otf.analyze_features
    return analyze(otfdata.gpos), analyze(otfdata.gsub)
end

local a_to_script   = { }
local a_to_language = { }

do

    local context_setups  = fonts.define.specify.context_setups
    local context_numbers = fonts.define.specify.context_numbers

    function fonts.otf.set_dynamics(tfmdata,attribute,features) --currently experimental and slow / hackery
        local shared = tfmdata.shared
        if shared then
            local dynamics = shared.dynamics
            if dynamics then
                features = features or context_setups[context_numbers[attribute]]
                if features then
                    local script   = features.script   or 'dflt'
                    local language = features.language or 'dflt'
                    local ds = dynamics[script]
                    if not ds then
                        ds = { }
                        dynamics[script] = ds
                    end
                    local dsl = ds[language]
                    if not dsl then
                        dsl = { }
                        ds[language] = dsl
                    end
                    local dsla = dsl[attribute]
                    if dsla then
                        return dsla
                    else
                        a_to_script  [attribute] = script
                        a_to_language[attribute] = language
                        dsla = { }
                        local otfdata = shared.otfdata
                        local methods = fonts.methods.node.otf
                        local initializers = fonts.initializers.node.otf
                        local gposfeatures, gsubfeatures = fonts.otf.analyze_only(otfdata,features)
                        local default = fonts.otf.features.default
                        local function register(list)
                            if list then
                                for i=1,#list do
                                    local f = list[i]
                                    local value = features[f] or default[f]
                                    if value then
                                        local i, m = initializers[f], methods[f]
                                        if i then
                                            i(tfmdata,value)
                                        end
                                        if m then
                                            dsla[#dsla+1] = m
                                        end
                                    end
                                end
                            end
                        end
                        register(fonts.triggers)
                        register(gsubfeatures)
                        register(gposfeatures)
                        dynamics[script][language][attribute] = dsla
                        return dsla
                    end
                end
            end
        end
        return { } -- todo: false
    end

end

-- scripts

fonts.otf.default_language = 'latn'
fonts.otf.default_script   = 'dflt'

function fonts.otf.valid_feature(otfdata,kind,script,language) -- return hash is faster
    if otfdata.luatex.ctx_always[kind] then
        script, language = 'dflt', 'dflt'
    else
        script   = script   or fonts.otf.default_script
        language = language or fonts.otf.default_language
    end
    script, language = script:lower(), language:lower() -- will go away, we will lowercase values
    local ft = otfdata.luatex.subtables[kind]
    local st = ft[script]
    return false, otfdata.luatex.always_valid, st and st[language] and st[language].valid
end

function fonts.otf.some_valid_feature(otfdata,kind,script,language)
    if otfdata.luatex.ctx_always[kind] then
        script, language = 'dflt', 'dflt'
    else
        script   = script   or fonts.otf.default_script
        language = language or fonts.otf.default_language
        script, language = script:lower(), language:lower() -- will go away, we will lowercase values
    end
    local t = otfdata.luatex.subtables[kind]
    if t and t[script] and t[script][language] and t[script][language].valid then
        return t[script][language].valid
    else
        return { }
    end
end

function fonts.otf.features.aux.resolve_ligatures(tfmdata,ligatures,kind)
    local otfdata = tfmdata.shared.otfdata
    local unicodes  = otfdata.luatex.unicodes
    local chars = tfmdata.characters
    local changed = tfmdata.changed or { }
    local done  = { }
    kind = kind or "unknown"
    local trace = fonts.otf.trace_features
    while true do
        local ok = false
        for k,v in pairs(ligatures) do
            local lig = v[1]
            if not done[lig] then
                local ligs = { }
                for s in lig:gmatch("[^ ]+") do
                    ligs[#ligs+1] = s
                end
                if #ligs == 2 then
                    local c, f, s = chars[v[2]], ligs[1], ligs[2]
                    local uf, us = unicodes[f], unicodes[s]
                    if changed[uf] or changed[us] then
                        if trace then
                            logs.report("define otf",string.format("%s: %s (%s) + %s (%s) ignored",kind,f,uf,s,us))
                        end
                    else
                        local first, second = chars[uf], us
                        if first and second then
                            local t = first.ligatures
                            if not t then
                                t = { }
                                first.ligatures = t
                            end
                            t[second] = {
                                char = unicodes[c.description.name],
                                type = 0
                            }
                            if trace then
                                logs.report("define otf",string.format("%s: %s (%s) + %s (%s) = %s (%s)",kind,f,uf,s,us,c.description.name,unicodes[c.description.name]))
                            end
                        end
                    end
                    ok, done[lig] = true, c.description.name
                end
            end
        end
        if ok then
            for d,n in pairs(done) do
                local pattern = "^(" .. d .. ") "
                for k,v in pairs(ligatures) do
                    v[1] = v[1]:gsub(pattern, function(str)
                        return n .. " "
                    end)
                end
            end
        else
            break
        end
    end
end

function fonts.otf.features.prepare_base_substitutions(tfmdata,kind,value) -- we can share some code with the node features
    if value then
        local ligatures = { }
        local otfdata = tfmdata.shared.otfdata
        local unicodes = otfdata.luatex.unicodes
        local trace = fonts.otf.trace_features
        local chars = tfmdata.characters
        local somevalid = fonts.otf.some_valid_feature(otfdata,kind,tfmdata.script,tfmdata.language)
        if not table.is_empty(somevalid) then
            tfmdata.changed = tfmdata.changed or { }
            local changed = tfmdata.changed
            local glyphs = otfdata.glyphs
            for k,c in pairs(chars) do
                local o = glyphs[c.description.index]
                if o and o.lookups then
                    for lookup,ps in pairs(o.lookups) do
                        if somevalid[lookup] then
                            for i=1,#ps do
                                local p = ps[i]
                                local t = p[1]
                                if t == 'substitution' then
                                    local pv = p[2] -- p.variant
                                    if pv then
                                        local upv = unicodes[pv]
                                        if upv and chars[upv] then
                                            if trace then
                                                logs.report("define otf",string.format("%s: %s (%s) => %s (%s)",kind,chars[k].description.name,k,chars[upv].description.name,upv))
                                            end
                                            chars[k] = chars[upv]
                                            changed[k] = true
                                        end
                                    end
                                elseif t == 'alternate' then
                                    local pc = p[2] -- p.components
                                    if pc then
                                        pc = pa.components:match("([^ ]+)")
                                        if pc then
                                            local upc = unicodes[pc]
                                            if upc and chars[upc] then
                                                if trace then
                                                    logs.report("define otf",string.format("%s: %s (%s) => %s (%s)",kind,chars[k].description.name,k,chars[upc].description.name,upc))
                                                end
                                                chars[k] = chars[upc]
                                                changed[k] = true
                                            end
                                        end
                                    end
                                elseif t == 'ligature' and not changed[k] then
                                    local pc = p[2]
                                    if pc then
                                        if trace then
                                            logs.report("define otf",string.format("%s: %s => %s (%s)",kind,pc,chars[k].description.name,k))
                                        end
                                        ligatures[#ligatures+1] = { pc, k }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            fonts.otf.features.aux.resolve_ligatures(tfmdata,ligatures,kind)
        end
    else
        tfmdata.ligatures = tfmdata.ligatures or { }
    end
end

function fonts.initializers.base.otf.liga(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'liga',value) end
function fonts.initializers.base.otf.dlig(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'dlig',value) end
function fonts.initializers.base.otf.rlig(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'rlig',value) end
function fonts.initializers.base.otf.hlig(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'hlig',value) end
function fonts.initializers.base.otf.pnum(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'pnum',value) end
function fonts.initializers.base.otf.onum(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'onum',value) end
function fonts.initializers.base.otf.tnum(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'tnum',value) end
function fonts.initializers.base.otf.lnum(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'lnum',value) end
function fonts.initializers.base.otf.zero(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'zero',value) end
function fonts.initializers.base.otf.smcp(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'smcp',value) end
function fonts.initializers.base.otf.cpsp(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'cpsp',value) end
function fonts.initializers.base.otf.c2sc(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'c2sc',value) end
function fonts.initializers.base.otf.ornm(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'ornm',value) end
function fonts.initializers.base.otf.aalt(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'aalt',value) end

function fonts.initializers.base.otf.hwid(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'hwid',value) end
function fonts.initializers.base.otf.fwid(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'fwid',value) end

-- Here comes the real thing ... node processing! The next session prepares
-- things. The main features (unchained by rules) have their own caches,
-- while the private ones cache locally.

do

    fonts.otf.features.prepare = { }

    function fonts.otf.features.prepare.feature(tfmdata,kind,value)
        if value then
            local language, script = tfmdata.language or "dflt", tfmdata.script or "dflt"
            local shared = tfmdata.shared
            local otfdata = shared.otfdata
            local lookuptable = fonts.otf.valid_subtable(otfdata,kind,script,language)
            if lookuptable then
                local fullkind = kind .. script .. language
                if not shared.lookuptable [fullkind] then
                --~ print(tfmdata,file.basename(tfmdata.fullname or ""),kind,script,language,lookuptable,fullkind)
                    local processes = { }
                    -- featuredata and featurecache are indexed by lookup so we can share them
                    shared.featuredata [kind]     = shared.featuredata [kind] or { }
                    shared.featurecache[kind]     = shared.featurecache[kind] or false -- signal
                    shared.lookuptable [fullkind] = lookuptable
                    shared.processes   [fullkind] = processes
                    local types = otfdata.luatex.name_to_type
                    local flags = otfdata.luatex.ignore_flags
                    local preparers = fonts.otf.features.prepare
                    local process = fonts.otf.features.process
                    local falsetable = { false, false, false }
                    for i=1,#lookuptable do
                        local lookupname = lookuptable[i]
                        local lookuptype = types[lookupname]
                        local prepare = preparers[lookuptype]
                        if prepare then
                            local processdata = prepare(tfmdata,kind,lookupname)
                            if processdata then
                                local processflags = flags[lookupname] or falsetable --- share false table
                                processes[#processes+1] = { process[lookuptype], lookupname, processdata, processflags }
                            end
                        end
                    end
                end
            end
        end
    end

    -- helper: todo, we don't need to store non local ones for chains so we can pass the
    -- validator as parameter

    local pairs = pairs

    function fonts.otf.features.collect_ligatures(tfmdata,kind) -- ligs are spread all over the place
        local otfdata = tfmdata.shared.otfdata
        local unicodes = tfmdata.shared.otfdata.luatex.unicodes -- actually the char index is ok too
        local trace = fonts.otf.trace_features
        local ligatures = { }
        local function collect(lookup,o,ps)
            for i=1,#ps do
                local p = ps[i]
                if p[1] == 'ligature' then
                    if trace then
                        logs.report("define otf",string.format("feature %s ligature %s => %s",kind,p[2],o.name))
                    end
                    local t = ligatures[lookup]
                    if not t then
                        t = { }
                        ligatures[lookup] = t
                    end
                    local first = true
                    for s in p[2]:gmatch("[^ ]+") do
                        local u = unicodes[s]
                        if first then
                            if not t[u] then
                                t[u] = { { } }
                            end
                            t = t[u]
                            first = false
                        else
                            local t1 = t[1]
                            if not t1[u] then
                                t1[u] = { { } }
                            end
                            t = t1[u]
                        end
                    end
                    t[2] = o.unicode
                end
            end
        end
        local forced, always, okay = fonts.otf.valid_feature(otfdata,kind,tfmdata.script,tfmdata.language)
        for _,o in pairs(otfdata.glyphs) do
            local lookups = o.lookups
            if lookups then
                if forced then
                    for lookup, ps in pairs(lookups) do                                        collect(lookup,o,ps)     end
                elseif okay then
                    for lookup, ps in pairs(lookups) do if always[lookup] or okay[lookup] then collect(lookup,o,ps) end end
                else
                    for lookup, ps in pairs(lookups) do if always[lookup]                 then collect(lookup,o,ps) end end
                end
            end
        end
        return ligatures
    end

    -- gsub_single        -> done
    -- gsub_multiple      -> done
    -- gsub_alternate     -> done
    -- gsub_ligature      -> done
    -- gsub_context       -> todo
    -- gsub_contextchain  -> done
    -- gsub_reversechain  -> todo

    -- we used to share code in the following functions but that was relatively
    -- due to extensive calls to functions (easily hundreds of thousands per
    -- document)

    function fonts.otf.features.prepare.gsub_single(tfmdata,kind,lookupname)
        local featuredata = tfmdata.shared.featuredata[kind]
        local substitutions = featuredata[lookupname]
        if not substitutions then
            substitutions = { }
            featuredata[lookupname] = substitutions
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local trace = fonts.otf.trace_features
            for _, o in pairs(otfdata.glyphs) do
                local lookups = o.lookups
                if lookups then
                    for lookup,ps in pairs(lookups) do
                        if lookup == lookupname then
                            for i=1,#ps do
                                local p = ps[i]
                                if p[1] == 'substitution' then
                                    local old, new = o.unicode, unicodes[p[2]]
                                    substitutions[old] =  new
                                    if trace then
                                        logs.report("define otf",string.format("%s:%s substitution %s => %s",kind,lookupname,old,new))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return substitutions
    end

    function fonts.otf.features.prepare.gsub_multiple(tfmdata,kind,lookupname)
        local featuredata = tfmdata.shared.featuredata[kind]
        local substitutions = featuredata[lookupname]
        if not substitutions then
            substitutions = { }
            featuredata[lookupname] = substitutions
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local trace = fonts.otf.trace_features
            for _,o in pairs(otfdata.glyphs) do
                local lookups = o.lookups
                if lookups then
                    for lookup,ps in pairs(lookups) do
                        if lookup == lookupname then
                            for i=1,#ps do
                                local p = ps[i]
                                if p[1] == 'multiple' then
                                    local old, new = o.unicode, { }
                                    substitutions[old] = new
                                    for pc in p[2]:gmatch("[^ ]+") do
                                        new[#new+1] = unicodes[pc]
                                    end
                                    if trace then
                                        logs.report("define otf",string.format("%s:%s multiple %s => %s",kind,lookupname,old,table.concat(new," ")))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return substitutions
    end

    function fonts.otf.features.prepare.gsub_alternate(tfmdata,kind,lookupname)
        -- todo: configurable preference list
        local featuredata = tfmdata.shared.featuredata[kind]
        local substitutions = featuredata[lookupname]
        if not substitutions then
            featuredata[lookupname] = { }
            substitutions = featuredata[lookupname]
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local trace = fonts.otf.trace_features
            for _,o in pairs(otfdata.glyphs) do
                local lookups = o.lookups
                if lookups then
                    for lookup,ps in pairs(lookups) do
                        if lookup == lookupname then
                            for i=1,#ps do
                                local p = ps[i]
                                if p[1] == 'alternate' then
                                    local old = o.unicode
                                    local t = { }
                                    for pc in p[2]:gmatch("[^ ]+") do
                                        t[#t+1] = unicodes[pc]
                                    end
                                    substitutions[old] =  t
                                    if trace then
                                        logs.report("define otf",string.format("%s:%s alternate %s => %s",kind,lookupname,old,table.concat(substitutions,"|")))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return substitutions
    end

    function fonts.otf.features.prepare.gsub_ligature(tfmdata,kind,lookupname)
        -- we collect them for all lookups, this saves loops, we only use the
        -- lookupname for testing, we need to check if this leads to redundant
        -- collections
        local ligatures = tfmdata.shared.featuredata[kind]
        if not ligatures[lookupname] then
            ligatures = fonts.otf.features.collect_ligatures(tfmdata,kind)
            tfmdata.shared.featuredata[kind] = ligatures
        end
        return ligatures[lookupname]
    end

    function fonts.otf.features.prepare.contextchain(tfmdata,kind,lookupname)
        local featuredata = tfmdata.shared.featuredata[kind]
        local contexts = featuredata[lookupname]
        if not contexts then
            featuredata[lookupname] = { }
            contexts = featuredata[lookupname]
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local internals = otfdata.luatex.internals
            local flags = otfdata.luatex.ignore_flags
            local types = otfdata.luatex.name_to_type
            otfdata.luatex.covers = otfdata.luatex.covers or { }
            local characters = tfmdata.characters
            local cache = otfdata.luatex.covers
            local function uncover(covers)
                -- lpeg hardly faster (.005 sec on mk)
                if covers then
                    local result = { }
                    for n=1,#covers do
                        local c = covers[n]
                        local cc = cache[c]
                        if not cc then
                            local t = { }
                            for s in c:gmatch("[^ ]+") do
                                t[unicodes[s]] = true
                            end
                            cache[c] = t
                            result[n] = t
                        else
                            result[n] = cc
                        end
                    end
                    return result
                else
                    return { }
                end
            end
            local lookupdata = otfdata.lookups[lookupname]
            if not lookupdata then
                logs.error("otf process", string.format("missing lookupdata table %s",lookupname))
            elseif lookupdata.rules then
                local rules = lookupdata.rules
                for nofrules=1,#rules do
                    local rule = rules[nofrules]
                    local coverage = rule.coverage
                    if coverage and coverage.current then
                        local current = uncover(coverage.current)
                        local before = uncover(coverage.before)
                        local after = uncover(coverage.after)
                        if current[1] then
                            local lookups, lookuptype = rule.lookups, 'self'
                            -- for the moment only lookup index 1
                            if lookups then
                                if #lookups > 1 then
                                    logs.report("otf process","WARNING: more than one lookup in rule")
                                end
                                lookuptype = types[lookups[1]]
                            end
                            for unic, _ in pairs(current[1]) do
                                local t = contexts[unic]
                                if not t then
                                    contexts[unic] = { lookups={}, flags=flags[lookupname] }
                                    t = contexts[unic].lookups
                                end
                                t[#t+1] = { nofrules, lookuptype, current, before, after, lookups }
                            end
                        end
                    end
                end
            end
        end
        return contexts
    end

    fonts.otf.features.prepare.gsub_context             = fonts.otf.features.prepare.contextchain
    fonts.otf.features.prepare.gsub_contextchain        = fonts.otf.features.prepare.contextchain
    fonts.otf.features.prepare.gsub_reversecontextchain = fonts.otf.features.prepare.contextchain

    -- ruled->lookup=ks_latn_l_27_c_4 => internal[ls_l_84] => valid[ls_l_84_s]

    -- gpos_mark2base     -> done
    -- gpos_mark2ligature -> done
    -- gpos_mark2mark     -> done
    -- gpos_single        -> not done
    -- gpos_pair          -> not done
    -- gpos_cursive       -> not done
    -- gpos_context       -> not done
    -- gpos_contextchain  -> not done

    function fonts.otf.features.prepare.anchors(tfmdata,kind,lookupname) -- tracing
        local featuredata = tfmdata.shared.featuredata[kind]
        local anchors = featuredata[lookupname]
        if not anchors then
            featuredata[lookupname] = { }
            anchors = featuredata[lookupname]
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local validanchors = { }
            local glyphs = otfdata.glyphs
            if otfdata.anchor_classes then
                local classes = otfdata.anchor_classes
                for k=1,#classes do
                    local class = classes[k]
                    if class.lookup == lookupname then
                        validanchors[class.name] = true
                    end
                end
            end
            for _,o in pairs(glyphs) do
                local oanchor = o.anchors
                if oanchor then
                    local t, ok = { }, false
                    for type, anchors in pairs(oanchor) do -- types
                        local tt = false
                        for name, anchor in pairs(anchors) do
                            if validanchors[name] then
                                if not tt then
                                    tt = { [name] = anchor }
                                    t[type] = tt
                                    ok = true
                                else
                                    tt[name] = anchor
                                end
                            end
                        end
                    end
                    if ok then
                        anchors[o.unicode] = t
                    end
                end
            end
        end
        return anchors
    end

    fonts.otf.features.prepare.gpos_mark2base     = fonts.otf.features.prepare.anchors
    fonts.otf.features.prepare.gpos_mark2ligature = fonts.otf.features.prepare.anchors
    fonts.otf.features.prepare.gpos_mark2mark     = fonts.otf.features.prepare.anchors
    fonts.otf.features.prepare.gpos_cursive       = fonts.otf.features.prepare.anchors
    fonts.otf.features.prepare.gpos_context       = fonts.otf.features.prepare.contextchain
    fonts.otf.features.prepare.gpos_contextchain  = fonts.otf.features.prepare.contextchain

    function fonts.otf.features.prepare.gpos_single(tfmdata,kind,lookupname)
        logs.report("otf define","gpos_single not yet supported")
    end

    --  ["kerns"]={ { ["char"]="ytilde", ["lookup"]="pp_l_1_s", ["off"]=-83, ...
    --  ["mykerns"] = { ["pp_l_1_s"] = { [67] = -28, ...

    function fonts.otf.features.prepare.gpos_pair(tfmdata,kind,lookupname)
        local featuredata = tfmdata.shared.featuredata[kind]
        local kerns = featuredata[lookupname]
        if not kerns then
            local trace = fonts.otf.trace_features
            featuredata[lookupname] = { }
            kerns = featuredata[lookupname]
            local otfdata = tfmdata.shared.otfdata
            local unicodes = otfdata.luatex.unicodes
            local glyphs = otfdata.glyphs
            -- ff has isolated kerns in a separate table
            for k,o in pairs(glyphs) do
                local list = o.mykerns
                if list then
                    local omk = list[lookupname]
                    if omk then
                        local one = o.unicode
                        for char, off in pairs(omk) do
                            local two = char
                            local krn = kerns[one]
                            if krn then
                                krn[two] = off
                            else
                                kerns[one] = { two = off }
                            end
                            if trace then
                                logs.report("define otf",string.format("feature %s kern pair %s - %s",kind,one,two))
                            end
                        end
                    end
                elseif o.kerns then
                    local one = o.unicode
                    local okerns = o.kerns
                    for ok=1,#okerns do
                        local k = okerns[ok]
                        if k.lookup == lookupname then
                            local char = k.char
                            if char then
                                local two = unicodes[char]
                                local krn = kerns[one]
                                if krn then
                                    krn[two] = k.off
                                else
                                    kerns[one] = { two = k.off }
                                end
                                if trace then
                                    logs.report("define otf",string.format("feature %s kern pair %s - %s",kind,one,two))
                                end
                            end
                        end
                    end
                end
                list = o.lookups
                if list then
                    local one = o.unicode
                    for lookup,ps in pairs(list) do
                        if lookup == lookupname then
                            for i=1,#ps do
                                local p = ps[i]
                                if p[1] == 'pair' then
                                    local two = unicodes[p[2]]
                                    local krn = kerns[one]
                                    if krn then
                                        krn[two] = p
                                    else
                                        kerns[one] = { two = p }
                                    end
                                    if trace then
                                        logs.report("define otf",string.format("feature %s kern pair %s - %s",kind,one,two))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return kerns
    end

    fonts.otf.features.prepare.gpos_contextchain = fonts.otf.features.prepare.contextchain

end

-- can be generalized: one loop in main

do

    local prepare = fonts.otf.features.prepare.feature

    function fonts.initializers.node.otf.aalt(tfm,value) return prepare(tfm,'aalt',value) end
    function fonts.initializers.node.otf.afrc(tfm,value) return prepare(tfm,'afrc',value) end
    function fonts.initializers.node.otf.akhn(tfm,value) return prepare(tfm,'akhn',value) end
    function fonts.initializers.node.otf.c2pc(tfm,value) return prepare(tfm,'c2pc',value) end
    function fonts.initializers.node.otf.c2sc(tfm,value) return prepare(tfm,'c2sc',value) end
    function fonts.initializers.node.otf.calt(tfm,value) return prepare(tfm,'calt',value) end
    function fonts.initializers.node.otf.case(tfm,value) return prepare(tfm,'case',value) end
    function fonts.initializers.node.otf.ccmp(tfm,value) return prepare(tfm,'ccmp',value) end
    function fonts.initializers.node.otf.clig(tfm,value) return prepare(tfm,'clig',value) end
    function fonts.initializers.node.otf.cpsp(tfm,value) return prepare(tfm,'cpsp',value) end
    function fonts.initializers.node.otf.cswh(tfm,value) return prepare(tfm,'cswh',value) end
    function fonts.initializers.node.otf.curs(tfm,value) return prepare(tfm,'curs',value) end
    function fonts.initializers.node.otf.dlig(tfm,value) return prepare(tfm,'dlig',value) end
    function fonts.initializers.node.otf.dnom(tfm,value) return prepare(tfm,'dnom',value) end
    function fonts.initializers.node.otf.expt(tfm,value) return prepare(tfm,'expt',value) end
    function fonts.initializers.node.otf.fin2(tfm,value) return prepare(tfm,'fin2',value) end
    function fonts.initializers.node.otf.fin3(tfm,value) return prepare(tfm,'fin3',value) end
    function fonts.initializers.node.otf.fina(tfm,value) return prepare(tfm,'fina',value) end
    function fonts.initializers.node.otf.frac(tfm,value) return prepare(tfm,'frac',value) end
    function fonts.initializers.node.otf.fwid(tfm,value) return prepare(tfm,'fwid',value) end
    function fonts.initializers.node.otf.haln(tfm,value) return prepare(tfm,'haln',value) end
    function fonts.initializers.node.otf.hist(tfm,value) return prepare(tfm,'hist',value) end
    function fonts.initializers.node.otf.hkna(tfm,value) return prepare(tfm,'hkna',value) end
    function fonts.initializers.node.otf.hlig(tfm,value) return prepare(tfm,'hlig',value) end
    function fonts.initializers.node.otf.hngl(tfm,value) return prepare(tfm,'hngl',value) end
    function fonts.initializers.node.otf.hwid(tfm,value) return prepare(tfm,'hwid',value) end
    function fonts.initializers.node.otf.init(tfm,value) return prepare(tfm,'init',value) end
    function fonts.initializers.node.otf.isol(tfm,value) return prepare(tfm,'isol',value) end
    function fonts.initializers.node.otf.ital(tfm,value) return prepare(tfm,'ital',value) end
    function fonts.initializers.node.otf.jp78(tfm,value) return prepare(tfm,'jp78',value) end
    function fonts.initializers.node.otf.jp83(tfm,value) return prepare(tfm,'jp83',value) end
    function fonts.initializers.node.otf.jp90(tfm,value) return prepare(tfm,'jp90',value) end
    function fonts.initializers.node.otf.kern(tfm,value) return prepare(tfm,'kern',value) end
    function fonts.initializers.node.otf.liga(tfm,value) return prepare(tfm,'liga',value) end
    function fonts.initializers.node.otf.lnum(tfm,value) return prepare(tfm,'lnum',value) end
    function fonts.initializers.node.otf.locl(tfm,value) return prepare(tfm,'locl',value) end
    function fonts.initializers.node.otf.mark(tfm,value) return prepare(tfm,'mark',value) end
    function fonts.initializers.node.otf.med2(tfm,value) return prepare(tfm,'med2',value) end
    function fonts.initializers.node.otf.medi(tfm,value) return prepare(tfm,'medi',value) end
    function fonts.initializers.node.otf.mgrk(tfm,value) return prepare(tfm,'mgrk',value) end
    function fonts.initializers.node.otf.mkmk(tfm,value) return prepare(tfm,'mkmk',value) end
    function fonts.initializers.node.otf.nalt(tfm,value) return prepare(tfm,'nalt',value) end
    function fonts.initializers.node.otf.nlck(tfm,value) return prepare(tfm,'nlck',value) end
    function fonts.initializers.node.otf.nukt(tfm,value) return prepare(tfm,'nukt',value) end
    function fonts.initializers.node.otf.numr(tfm,value) return prepare(tfm,'numr',value) end
    function fonts.initializers.node.otf.onum(tfm,value) return prepare(tfm,'onum',value) end
    function fonts.initializers.node.otf.ordn(tfm,value) return prepare(tfm,'ordn',value) end
    function fonts.initializers.node.otf.ornm(tfm,value) return prepare(tfm,'ornm',value) end
    function fonts.initializers.node.otf.pnum(tfm,value) return prepare(tfm,'pnum',value) end
    function fonts.initializers.node.otf.pref(tfm,value) return prepare(tfm,'pref',value) end
    function fonts.initializers.node.otf.pres(tfm,value) return prepare(tfm,'pres',value) end
    function fonts.initializers.node.otf.pstf(tfm,value) return prepare(tfm,'pstf',value) end
    function fonts.initializers.node.otf.rlig(tfm,value) return prepare(tfm,'rlig',value) end
    function fonts.initializers.node.otf.rphf(tfm,value) return prepare(tfm,'rphf',value) end
    function fonts.initializers.node.otf.salt(tfm,value) return prepare(tfm,'salt',value) end
    function fonts.initializers.node.otf.sinf(tfm,value) return prepare(tfm,'sinf',value) end
    function fonts.initializers.node.otf.smcp(tfm,value) return prepare(tfm,'smcp',value) end
    function fonts.initializers.node.otf.smpl(tfm,value) return prepare(tfm,'smpl',value) end
    function fonts.initializers.node.otf.ss01(tfm,value) return prepare(tfm,'ss01',value) end
    function fonts.initializers.node.otf.ss02(tfm,value) return prepare(tfm,'ss02',value) end
    function fonts.initializers.node.otf.ss03(tfm,value) return prepare(tfm,'ss03',value) end
    function fonts.initializers.node.otf.ss04(tfm,value) return prepare(tfm,'ss04',value) end
    function fonts.initializers.node.otf.ss05(tfm,value) return prepare(tfm,'ss05',value) end
    function fonts.initializers.node.otf.ss06(tfm,value) return prepare(tfm,'ss06',value) end
    function fonts.initializers.node.otf.ss07(tfm,value) return prepare(tfm,'ss07',value) end
    function fonts.initializers.node.otf.ss08(tfm,value) return prepare(tfm,'ss08',value) end
    function fonts.initializers.node.otf.ss09(tfm,value) return prepare(tfm,'ss09',value) end
    function fonts.initializers.node.otf.subs(tfm,value) return prepare(tfm,'subs',value) end
    function fonts.initializers.node.otf.sups(tfm,value) return prepare(tfm,'sups',value) end
    function fonts.initializers.node.otf.swsh(tfm,value) return prepare(tfm,'swsh',value) end
    function fonts.initializers.node.otf.titl(tfm,value) return prepare(tfm,'titl',value) end
    function fonts.initializers.node.otf.tnam(tfm,value) return prepare(tfm,'tnam',value) end
    function fonts.initializers.node.otf.tnum(tfm,value) return prepare(tfm,'tnum',value) end
    function fonts.initializers.node.otf.trad(tfm,value) return prepare(tfm,'trad',value) end
    function fonts.initializers.node.otf.unic(tfm,value) return prepare(tfm,'unic',value) end
    function fonts.initializers.node.otf.zero(tfm,value) return prepare(tfm,'zero',value) end

end

do

    -- todo: use nodes helpers

    local glyph         = node.id('glyph')
    local glue          = node.id('glue')
    local disc          = node.id('disc')

    local fontdata      = fonts.tfm.id
    local has_attribute = node.has_attribute
    local set_attribute = node.set_attribute
    local state         = attributes.numbers['state'] or 100
    local marknumber    = attributes.numbers['mark']  or 200
    local format        = string.format
    local report        = logs.report
    local scale         = tex.scale

    fonts.otf.features.process = { }

    -- we share some vars here, after all, we have no nested lookups and
    -- less code

    local tfmdata     = false
    local otfdata     = false
    local characters  = false
    local marks       = false
    local glyphs      = false
    local currentfont = false

    -- we cheat a bit and assume that a font,attr combination are kind of ranged

    local context_setups  = fonts.define.specify.context_setups
    local context_numbers = fonts.define.specify.context_numbers

    function fonts.otf.features.process.feature(head,font,attr,kind,attribute)
        tfmdata = fontdata[font]
        local shared = tfmdata.shared
        otfdata = shared.otfdata
        characters = tfmdata.characters
        marks = otfdata.luatex.marks
        glyphs = otfdata.glyphs
        currentfont = font
        local script, language
        if attr and attr > 0 then
            local features = context_setups[context_numbers[attr]]
            language, script = features.language or "dflt", features.script or "dflt"
        else
            language, script = tfmdata.language or "dflt", tfmdata.script or "dflt"
        end
        local fullkind = kind .. script .. language
        local lookuptable = shared.lookuptable[fullkind]
        if lookuptable then
            local types = otfdata.luatex.name_to_type
            local start, done, ok = head, false, false
            local processes = shared.processes[fullkind]
            if #processes == 1 then
                local p = processes[1]
                while start do -- evt splitsen
                    if start.id == glyph and start.subtype<256 and start.font == font and
                        (not attr or has_attribute(start,0,attr)) and -- dynamic feature
                        (not attribute or has_attribute(start,state,attribute)) then
                        -- we can make the p vars also global to this closure
                        local pp = p[3] -- all lookups
                        local pc = pp[start.char]
                        if pc then
                            start, ok = p[1](start,kind,p[2],pc,pp,p[4])
                            done = done or ok
                            if start then start = start.next end
                        else
                            start = start.next
                        end
                    else
                        start = start.next
                    end
                end
            else
                while start do
                    if start.id == glyph and start.subtype<256 and start.font == font and
                        (not attr or has_attribute(start,0,attr)) and -- dynamic feature
                        (not attribute or has_attribute(start,state,attribute)) then
                        for i=1,#processes do local p = processes[i]
                            local pp = p[3]
                            local pc = pp[start.char]
                            if pc then
                                start, ok = p[1](start,kind,p[2],pc,pp,p[4])
                                if ok then
                                    done = true
                                    break
                                elseif not start then
                                    break
                                end
                            end
                        end
                        if start then start = start.next end
                    else
                        start = start.next
                    end
                end
            end
            return head, done
        else
            return head, false
        end
    end

    -- we can assume that languages that use marks are not hyphenated
    -- we can also assume that at most one discretionary is present

    local function toligature(start,stop,char,markflag,discfound) -- brr head
        if start ~= stop then
            if discfound then
                local lignode = node.copy(start)
                lignode.font = start.font
                lignode.char = char
                lignode.subtype = 2
                start = node.do_ligature_n(start, stop, lignode)
                if start.id == disc then
                    local prev = start.prev
                    start = start.next
                end
            else
                local deletemarks = markflag ~= "mark"
                start.components = node.copy_list(start,stop)
                node.slide(start.components)
                -- todo: components
                start.subtype = 2
                start.char = char
                local marknum = 1
                local next = start.next
                while true do
                    if marks[next.char] then
                        if not deletemarks then
                            set_attribute(next,marknumber,marknum)
                        end
                    else
                        marknum = marknum + 1
                    end
                    if next == stop then
                        break
                    else
                        next = next.next
                    end
                end
                next = stop.next
                while next do
                    if next.id == glyph and next.font == currentfont and marks[next.char] then
                        set_attribute(next,marknumber,marknum)
                        next = next.next
                    else
                        break
                    end
                end
                local next = start.next
--~                 while true do
--~                     if next == stop or deletemarks or marks[next.char] then
--~                         local crap = next
--~                         next.prev.next = next.next
--~                         if next.next then
--~                             next.next.prev = next.prev
--~                         end
--~                         if next == stop then
--~                             stop = crap.prev
--~                             node.free(crap)
--~                             break
--~                         else
--~                             next = next.next
--~                             node.free(crap)
--~                         end
--~                     else
--~                         next = next.next
--~                     end
--~                 end
                while true do
                    if next == stop or deletemarks or marks[next.char] then
                        local crap = next
                        local np, nn = next.prev, next.next
                        np.next = nn
                        if nn then
                            nn.prev = np
                        end
                        if next == stop then
                            stop = crap.prev
                            node.free(crap)
                            break
                        else
                            next = nn
                            node.free(crap)
                        end
                    else
                        next = nn
                    end
                end
            end
        end
        return start
    end

    function fonts.otf.features.process.gsub_single(start,kind,lookupname,replacements)
        if replacements then
            start.char = replacements
            if fonts.otf.trace_replacements then
                report("process otf",format("%s:%s replacing %s by %s",kind,lookupname,start.char,replacements))
            end
            return start, true
        else
            return start, false
        end
    end

    function fonts.otf.features.process.gsub_alternate(start,kind,lookupname,alternatives)
        if alternatives then
            start.char = alternatives[1] -- will be preference
            if fonts.otf.trace_replacements then
                report("process otf",format("%s:%s alternative %s => %s",kind,lookupname,start.char,table.concat(alternatives,"|")))
            end
            return start, true
        else
            return start, false
        end
    end

    function fonts.otf.features.process.gsub_multiple(start,kind,lookupname,multiples)
        if multiples then
            start.char = multiples[1]
            if #multiples > 1 then
                for k=2,#multiples do
                    local n = node.copy(start)
                    local sn = start.next
                    n.char = multiples[k]
                    n.next = sn
                    n.prev = start
                    if sn then
                        sn.prev = n
                    end
                    start.next = n
                    start = n
                end
            end
            if fonts.otf.trace_replacements then
                report("process otf",format("%s:%s alternative %s => %s",kind,lookupname,start.char,table.concat(multiples," ")))
            end
            return start, true
        else
            return start, false
        end
    end

    function fonts.otf.features.process.gsub_ligature(start,kind,lookupname,ligatures,alldata,flags)
        local s, stop, discfound = start.next, nil, false
        while s do
            local id = s.id
            if id == glyph and s.subtype<256 then
                if s.font == currentfont then
                    if marks[s.char] then
                        s = s.next
                    else
                        local lg = ligatures[1][s.char]
                        if not lg then
                            break
                        else
                            stop = s
                            ligatures = lg
                            s = s.next
                        end
                    end
                else
                    break
                end
            elseif id == disc then
                discfound = true
                s = s.next
            else
                break
            end
        end
        if stop and ligatures[2] then
            start = toligature(start,stop,ligatures[2],flags[1],discfound)
            if fonts.otf.trace_ligatures then
                report("process otf",format("%s: inserting ligature %s (%s)",kind,start.char,utf.char(start.char)))
            end
            return start, true
        end
        return start, false
    end

    -- again, using copies is more efficient than sharing code

    function fonts.otf.features.process.gpos_mark2base(start,kind,lookupname,baseanchors,anchors) -- maybe use copies
        local bases = baseanchors['basechar']
        if bases then
            local component = start.next
            if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                local trace = fonts.otf.trace_anchors
                local last, done = start, false
                local factor = tfmdata.factor
                while true do
                    local markanchors = anchors[component.char]
                    if markanchors then
                        local marks = markanchors['mark']
                        if marks then
                            for anchor,data in pairs(marks) do
                                local ba = bases[anchor]
                                if ba then
                                    local dx = scale(ba[1]-data[1], factor)
                                    local dy = scale(ba[2]-data[2], factor)
                                    component.xoffset = start.xoffset - dx
                                    component.yoffset = start.yoffset + dy
                                    if trace then
                                        report("process otf",format("%s: anchoring mark %s to basechar %s => (%s,%s) => (%s,%s)",kind,component.char,start.char,dx,dy,component.xoffset,component.yoffset))
                                    end
                                    done = true
                                    break
                                end
                            end
                        end
                        last = component
                    end
                    component = component.next
--~ if component and component.id == kern then
--~     component = component.next
--~ end
                    if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                        -- ok
                    else
                        break
                    end
                end
                return last, done
            end
        end
        return start, false
    end

    function fonts.otf.features.process.gpos_mark2ligature(start,kind,lookupname,baseanchors,anchors)
        local bases = baseanchors['baselig']
        if bases then
            local component = start.next
            if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                local trace = fonts.otf.trace_anchors
                local last, done = start, false
                local factor = tfmdata.factor
                while true do
                    local markanchors = anchors[component.char]
                    if markanchors then
                        local marks = markanchors['mark']
                        if marks then
                            for anchor,data in pairs(marks) do
                                local ba = bases[anchor]
                                if ba then
                                    local n = has_attribute(component,marknumber)
                                    local ban = ba[n]
                                    if ban then
                                        local dx = scale(ban[1]-data[1], factor)
                                        local dy = scale(ban[2]-data[2], factor)
                                        component.xoffset = start.xoffset - dx
                                        component.yoffset = start.yoffset + dy
                                        if trace then
                                            report("process otf",format("%s:%s:%s anchoring mark %s to baselig %s => (%s,%s) => (%s,%s)",kind,anchor,n,component.char,start.char,dx,dy,component.xoffset,component.yoffset))
                                        end
                                        done = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    last = component
                    component = component.next
--~ if component and component.id == kern then
--~     component = component.next
--~ end
                    if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                        -- ok
                    else
                        break
                    end
                end
                return last, done
            end
        end
        return start, false
    end

    function fonts.otf.features.process.gpos_mark2mark(start,kind,lookupname,baseanchors,anchors)
        -- we can stay in the loop for all anchors
        local bases = baseanchors['basemark']
        if bases then
            local component = start.next
            if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                local baseattr = has_attribute(start,marknumber) or 1
                local trace = fonts.otf.trace_anchors
                local last, done = start, false
                local factor = tfmdata.factor
                while true do
                    local markattr = has_attribute(component,marknumber) or 1
                    if baseattr == markattr then
                        local markanchors = anchors[component.char]
                        if markanchors then
                            local marks = markanchors['mark']
                            if marks then
                                for anchor,data in pairs(marks) do
                                    local ba = bases[anchor]
                                    if ba then
                                        local dx = scale(ba[1]-data[1], factor)
                                        local dy = scale(ba[2]-data[2], factor)
                                        component.xoffset = start.xoffset - dx
                                        component.yoffset = start.yoffset + dy
                                        if trace then
                                            report("process otf",format("%s:%s:%s anchoring mark %s to basemark %s => (%s,%s) => (%s,%s)",kind,anchor,markattr,start.char,component.char,dx,dy,component.xoffset,component.yoffset))
                                        end
                                        done = true
                                        break
                                    end
                                end
                            end
                        end
                        last = component
                        component = component.next
--~ if component and component.id == kern then
--~     component = component.next
--~ end
                        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                            -- ok
                        else
                            break
                        end
                    else
                        break
                    end
                end
                return last, done
            end
        end
        return start, false
    end

    function fonts.otf.features.process.gpos_cursive(start,kind,lookupname,exitanchors,anchors)
        local trace = fonts.otf.trace_anchors
        local next, done, x, y, total, t, first = start.next, false, 0, 0, 0, { }, nil
        local function finish()
            local i = 0
            local factor = tfmdata.factor
            while first do
                if characters[first.char].description.class == 'mark' then
                    first = first.next
                else
                    first.yoffset = scale(total, factor)
                --  first.yoffset = factor*total
                    if first == next then
                        break
                    else
                        i = i + 1
                        total = total - (t[i] or 0)
                        first = first.next
                    end
                end
            end
            x, y, total, t, first = 0, 0, 0, { }, nil
        end
        while next do
            if next.id == glyph and next.subtype<256 and next.font == currentfont then
                local nextchar = next.char
                if marks[nextchar] then
                    next = next.next
                else
                    local entryanchors, exitanchors = anchors[nextchar], anchors[start.char]
                    if entryanchors and exitanchors then
                        local centry, cexit = entryanchors['centry'], exitanchors['cexit']
                        if centry and cexit then
                            for anchor, entry in pairs(centry) do
                                local exit = cexit[anchor]
                                if exit then
                                    if not first then first = start end
                                    t[#t+1] = exit[2] + entry[2]
                                    total = total + t[#t]
                                    done = true
                                    break
                                end
                            end
                        else
                            finish()
                        end
                    else
                        finish()
                    end
                    start = next
                    next = start.next
                end
            else
                finish()
                break
            end
        end
        return start, done
    end

    function fonts.otf.features.process.gpos_single(start,kind,lookupname,basekerns,kerns)
        report("otf process","gpos_single not yet supported")
        return start, false
    end

    function fonts.otf.features.process.gpos_pair(start,kind,lookupname,basekerns,kerns)
        local next, prev, done = start.next, start, false
        -- to be optimized
        local trace = fonts.otf.trace_kerns
        local factor = tfmdata.factor
        while next and next.id == glyph and next.subtype<256 and next.font == currentfont do
            if characters[next.char].description.class == 'mark' then
                prev = next
                next = next.next
            else
                local krn = basekerns[next.char]
                if not krn then
                    -- skip
                elseif type(krn) == "table" then
                    local a, b = krn[3], krn[7]
                    if a and a ~= 0 then
                        local k = nodes.kern(scale(a,factor))
                        k.next = next
                        k.prev = prev
                        prev.next = k
                        next.prev = k
                        if trace then
                            -- todo
                        end
                    end
                    if b and b ~= 0 then
                        report("otf process","we need to do something with the second kern xoff " .. b)
                    end
                else
                    -- todo, just start, next = node.insert_before(head,next,nodes.kern(scale(kern,factor)))
                    local k = nodes.kern(scale(krn,factor))
                    k.next = next
                    k.prev = prev
                    prev.next = k
                    next.prev = k
                end
                break
            end
        end
        return start, done
    end

    local chainprocs = { } -- we can probably optimize this because they're all internal lookups

    -- For the moment we save each looked up glyph in the sequence, which is ok because
    -- each lookup in the chain has its own sequence. This saves memory. Only ligatures
    -- are stored in the featurecache, because we don't want to loop over all characters
    -- in order to locate them.

    -- We had a version that shared code, but it was too much a slow down
    -- todo n x n.

    function chainprocs.gsub_single(start,stop,kind,lookupname,sequence,lookups)
        local char = start.char
        local cacheslot = sequence[1]
        local replacement = cacheslot[char]
        if replacement == true then
            if lookups then
                local looks = glyphs[tfmdata.characters[char].description.index].lookups
                if looks then
                    local lookups = otfdata.luatex.internals[lookups[1]].lookups
                    local unicodes = otfdata.luatex.unicodes
                    for l=1,#lookups do
                        local lv = looks[lookups[l]]
                        if lv then
                            replacement = unicodes[lv[1][2]] or char
                            cacheslot[char] = replacement
                            break
                        end
                    end
                else
                    replacement, cacheslot[char] = char, char
                end
            else
                replacement, cacheslot[char] = char, char
            end
        end
        if fonts.otf.trace_replacements then
            report("otf chain",format("%s: replacing character %s by single %s",kind,char,replacement))
        end
        start.char = replacement
        return start
    end

    function chainprocs.gsub_multiple(start,stop,kind,lookupname,sequence,lookups)
        local char = start.char
        local cacheslot = sequence[1]
        local replacement = cacheslot[char]
        if replacement == true then
            if lookups then
                local looks = glyphs[tfmdata.characters[char].description.index].lookups
                if looks then
                    local lookups = otfdata.luatex.internals[lookups[1]].lookups
                    local unicodes = otfdata.luatex.unicodes
                    for l=1,#lookups do
                        local lv = looks[lookups[l]]
                        if lv then
                            replacement = { }
                            for c in lv[1][2]:gmatch("[^ ]+") do
                                replacement[#replacement+1] = unicodes[c]
                            end
                            cacheslot[char] = replacement
                            break
                        end
                    end
                else
                    replacement = { char }
                    cacheslot[char] = replacement
                end
            else
                replacement = { char }
                cacheslot[char] = replacement
            end
        end
        if fonts.otf.trace_replacements then
            report("otf chain",format("%s: replacing character %s by multiple",kind,char))
        end
        start.char = replacement[1]
        if #replacement > 1 then
            for k=2,#replacement do
                local n = node.copy(start)
                local sn = start.next
                n.char = replacement[k]
                n.next = sn
                n.prev = start
                if sn then
                    sn.prev = n
                end
                start.next = n
                start = n
            end
        end
        return start
    end

    function chainprocs.gsub_alternate(start,stop,kind,lookupname,sequence,lookups)
        local char = start.char
        local cacheslot = sequence[1]
        local replacement = cacheslot[char]
        if replacement == true then
            if lookups then
                local looks = glyphs[tfmdata.characters[char].description.index].lookups
                if looks then
                    local lookups = otfdata.luatex.internals[lookups[1]].lookups
                    local unicodes = otfdata.luatex.unicodes
                    for l=1,#lookups do
                        local lv = looks[lookups[l]]
                        if lv then
                            replacement = { }
                            for c in lv[1][2]:gmatch("[^ ]+") do
                                replacement[#replacement+1] = unicodes[c]
                            end
                            cacheslot[char] = replacement
                            break
                        end
                    end
                else
                    replacement = { char }
                    cacheslot[char] = replacement
                end
            else
                replacement = { char }
                cacheslot[char] = replacement
            end
        end
        if fonts.otf.trace_replacements then
            report("otf chain",format("%s: replacing character %s by alternate",kind,char))
        end
        start.char = replacement[1]
        return start
    end

    function chainprocs.gsub_ligature(start,stop,kind,lookupname,sequence,lookups,flags)
        if lookups then
            local featurecache = fontdata[currentfont].shared.featurecache
            if not featurecache[kind] then
                featurecache[kind] = fonts.otf.features.collect_ligatures(tfmdata,kind) -- double cached ?
            end
            local lookups = otfdata.luatex.internals[lookups[1]].lookups
            local ligaturecache = featurecache[kind]
            local trace = fonts.otf.trace_ligatures
            for i=1,#lookups do
                local ligatures = ligaturecache[lookups[i]]
                if ligatures and ligatures[start.char] then
                    ligatures = ligatures[start.char]
                    local s, discfound = start.next, false
                    while s do
                        local id = s.id
                        if id == disc then
                            s = s.next
                            discfound = true
                        elseif characters[s.char].description.class == 'mark' then
                            s = s.next
                        else
                            local lg = ligatures[1][s.char]
                            if not lg then
                                break
                            else
                                ligatures = lg
                                if s == stop then
                                    break
                                else
                                    s = s.next
                                end
                            end
                        end
                    end
                    if ligatures[2] then
                        if trace then
                            report("otf chain",format("%s: replacing character %s by ligature",kind,start.char))
                        end
                        return toligature(start,stop,ligatures[2],flags[1],discfound)
                    end
                    break
                end
            end
        end
        return stop
    end

    function chainprocs.gpos_mark2base(start,stop,kind,lookupname,sequence,lookups)
        local component = start.next
        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
            local char = start.char
            local anchortag = sequence[1][char]
            if anchortag == true then
                local classes = otfdata.anchor_classes
                for k=1,#classes do
                    local v = classes[k]
                    if v.lookup == lookupname and v.type == kind then
                        anchortag = v.name
                        sequence[1][char] = anchortag
                        break
                    end
                end
            end
            if anchortag ~= true then
                local glyph = glyphs[characters[char].description.index]
                if glyph.anchors and glyph.anchors[anchortag] then
                    local trace = fonts.otf.trace_anchors
                    local last, done = start, false
                    local baseanchors = glyph.anchors['basechar'][anchortag]
                    local factor = tfmdata.factor
                    while true do
                        local nextchar = component.char
                        local charnext = characters[nextchar]
                        local markanchors = glyphs[charnext.description.index].anchors['mark'][anchortag]
                        if markanchors then
                            for anchor,data in pairs(markanchors) do
                                local ba = baseanchors[anchor]
                                if ba then
                                    local dx = scale(ba[1]-data[1], factor)
                                    local dy = scale(ba[2]-data[2], factor)
                                    component.xoffset = start.xoffset - dx
                                    component.yoffset = start.yoffset + dy
                                    if trace then
                                        report("otf chain",format("%s: anchoring mark %s to basechar %s => (%s,%s) => (%s,%s)",kind,component.char,start.char,dx,dy,component.xoffset,component.yoffset))
                                    end
                                    done = true
                                    break
                                end
                            end
                        end
                        last = component
                        component = component.next
                        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                            -- ok
                        else
                            break
                        end
                    end
                    return last, done
                end
            end
        end
        return start, false
    end

    function chainprocs.gpos_mark2ligature(start,stop,kind,lookupname,sequence,lookups)
        local component = start.next
        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
            local char = start.char
            local anchortag = sequence[1][char]
            if anchortag == true then
                local classes = otfdata.anchor_classes
                for k=1,#classes do
                    local v = classes[k]
                    if v.lookup == lookupname and v.type == kind then
                        anchortag = v.name
                        sequence[1][char] = anchortag
                        break
                    end
                end
            end
            if anchortag ~= true then
                local glyph = glyphs[characters[char].description.index]
                if glyph.anchors and glyph.anchors[anchortag] then
                    local trace = fonts.otf.trace_anchors
                    local done = false
                    local last = start
                    local baseanchors = glyph.anchors['baselig'][anchortag]
                    local factor = tfmdata.factor
                    while true do
                        local nextchar = component.char
                        local charnext = characters[nextchar]
                        local markanchors = glyphs[charnext.description.index].anchors['mark'][anchortag]
                        if markanchors then
                            for anchor,data in pairs(markanchors) do
                                local ba = baseanchors[anchor]
                                if ba then
                                    local n = has_attribute(component,marknumber)
                                    local ban = ba[n]
                                    if ban then
                                        local dx = scale(ban[1]-data[1], factor)
                                        local dy = scale(ban[2]-data[2], factor)
                                        component.xoffset = start.xoffset - dx
                                        component.yoffset = start.yoffset + dy
                                        if trace then
                                            report("otf chain",format("%s: anchoring mark %s to baselig %s => (%s,%s) => (%s,%s)",kind,component.char,start.char,dx,dy,component.xoffset,component.yoffset))
                                        end
                                        done = true
                                        break
                                    end
                                end
                            end
                        end
                        last = component
                        component = component.next
                        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                            -- ok
                        else
                            break
                        end
                    end
                    return last, done
                end
            end
        end
        return start, false
    end

    function chainprocs.gpos_mark2mark(start,stop,kind,lookupname,sequence,lookups)
        local component = start.next
        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
            local char = start.char
            local anchortag = sequence[1][char]
            if anchortag == true then
                local classes = otfdata.anchor_classes
                for k=1,#classes do
                    local v = classes[k]
                    if v.lookup == lookupname and v.type == kind then
                        anchortag = v.name
                        sequence[1][char] = anchortag
                        break
                    end
                end
            end
            local baseattr = has_attribute(start,marknumber)
            local markattr = has_attribute(component,marknumber)
            if baseattr == markattr and anchortag ~= true then
                local glyph = glyphs[characters[char].description.index]
                if glyph.anchors and glyph.anchors[anchortag] then
                    local trace = fonts.otf.trace_anchors
                    local last, done = false
                    local baseanchors = glyph.anchors['basemark'][anchortag]
                    local factor = tfmdata.factor
                    while true do
                        local nextchar = component.char
                        local charnext = characters[nextchar]
                        local markanchors = glyphs[charnext.description.index].anchors['mark'][anchortag]
                        if markanchors then
                            for anchor,data in pairs(markanchors) do
                                local ba = baseanchors[anchor]
                                if ba then
                                    local dx = scale(ba[1]-data[1], factor)
                                    local dy = scale(ba[2]-data[2], factor)
                                    component.xoffset = start.xoffset - dx
                                    component.yoffset = start.yoffset + dy
                                    if trace then
                                        report("otf chain",format("%s: anchoring mark %s to basemark %s => (%s,%s) => (%s,%s)",kind,component.char,start.char,dx,dy,component.xoffset,component.yoffset))
                                    end
                                    done = true
                                    break
                                end
                            end
                        end
                        last = component
                        component = component.next
                        if component and component.id == glyph and component.subtype<256 and component.font == currentfont and marks[component.char] then
                            markattr = has_attribute(component,marknumber)
                            if baseattr ~= markattr then
                                break
                            end
                        else
                            break
                        end
                    end
                    return last, done
                end
            end
        end
        return start, false
    end

    function chainprocs.gpos_cursive(start,stop,kind,lookupname,sequence,lookups)
        report("otf chain","chainproc gpos_cursive not yet supported")
        return start
    end
    function chainprocs.gpos_single(start,stop,kind,lookupname,sequence,lookups)
        report("otf process","chainproc gpos_single not yet supported")
        return start
    end
    function chainprocs.gpos_pair(start,stop,kind,lookupname,sequence,lookups)
        report("otf process","chainproc gpos_pair not yet supported")
        return start
    end

    function chainprocs.self(start,stop,kind,lookupname,sequence,lookups)
        report("otf process","self refering lookup cannot happen")
        return stop
    end

    function fonts.otf.features.process.contextchain(start,kind,lookupname,contextdata)
        local done = false
        local contexts = contextdata.lookups
        local flags = contextdata.flags
        local skipmark, skipligature, skipbase = unpack(flags)
        for k=1,#contexts do
            local match, stop = true, start
            local rule, lookuptype, sequence, before, after, lookups = unpack(contexts[k])
            if #sequence > 0 then
                if #sequence == 1 then
                    match = sequence[1][start.char]
                else -- n = #sequence -> faster
                    for n=1,#sequence do
                        if stop then
                            local id = stop.id
                            if id == glyph and stop.subtype<256 and stop.font == currentfont then
                                local char = stop.char
                                local class = characters[char].description.class
                                if class == skipmark or class == skipligature or class == skipbase then
                                    -- skip 'm
                                elseif sequence[n][char] then
                                    if n < #sequence then
                                        stop = stop.next
                                    end
                                else
                                    match = false break
                                end
                            elseif id == disc then -- what to do with kerns?
                                stop = stop.next
                            else
                                match = false break
                            end
                        else
                            match = false break
                        end
                    end
                end
            end
            if match and #before > 0 then
                local prev = start.prev
                if prev then
                    if #before == 1 then
                        match = prev.id == glyph and prev.subtype<256 and prev.font == currentfont and before[1][prev.char]
                    else
                        for n=#before,1 do
                            if prev then
                                local id = prev.id
                                if id == glyph and prev.subtype<256 and prev.font == currentfont then -- normal char
                                    local char = prev.char
                                    local class = characters[char].description.class
                                    if class == skipmark or class == skipligature or class == skipbase then
                                        -- skip 'm
                                    elseif not before[n][char] then
                                        match = false break
                                    end
                                elseif id == disc then
                                    -- skip 'm
                                elseif not before[n][32] then
                                    match = false break
                                end
                                prev = prev.prev
                            elseif not before[n][32] then
                                match = false break
                            end
                        end
                    end
                elseif #before == 1 then
                    match = before[1][32]
                else
                    for n=#before,1 do
                        if not before[n][32] then
                            match = false break
                        end
                    end
                end
            end
            if match and #after > 0 then
                local next = stop.next
                if next then
                    if #after == 1 then
                        match = next.id == glyph and next.subtype<256 and next.font == currentfont and after[1][next.char]
                    else
                        for n=1,#after do
                            if next then
                                local id = next.id
                                if id == glyph and next.subtype<256 and next.font == currentfont then -- normal char
                                    local char = next.char
                                    local class = characters[char].description.class
                                    if class == skipmark or class == skipligature or class == skipbase then
                                        -- skip 'm
                                    elseif not after[n][char] then
                                        match = false break
                                    end
                                elseif id == disc then
                                    -- skip 'm
                                elseif not after[n][32] then -- brrr
                                    match = false break
                                end
                                next = next.next
                            elseif not after[n][32] then
                                match = false break
                            end
                        end
                    end
                elseif #after == 1 then
                    match = after[1][32]
                else
                    for n=1,#after do
                        if not after[n][32] then
                            match = false break
                        end
                    end
                end
            end
            if match then
                local trace = fonts.otf.trace_contexts
                if trace then
                    local char = start.char
                    report("otf chain",format("%s: rule %s of %s matches %s times at char %s (%s) lookuptype %s",kind,rule,lookupname,#sequence,char,utf.char(char),lookuptype))
                end
                if lookups then
                    local cp = chainprocs[lookuptype]
                    if cp then
                        start = cp(start,stop,kind,lookupname,sequence,lookups,flags)
                    else
                        report("otf chain",format("%s: lookuptype %s not supported yet for %s",kind,lookuptype,lookupname))
                    end
                elseif trace then
                    report("otf chain",format("%s: skipping match for %s",kind,lookupname))
                end
                done = true
                break
            end
        end
        return start, done
    end

    function fonts.otf.features.process.reversecontextchain(start,kind,lookupname,contextdata)
        -- there is only a single substitution here so it is a simple case of the normal one
        -- sequence is one character here and we swap the rest
        local done = false
        local contexts = contextdata.lookups
        local flags = contextdata.flags
        local skipmark, skipligature, skipbase = unpack(flags)
        for k=1,#contexts do
            local match, stop = true, start
            local rule, lookuptype, sequence, before, after, lookups = unpack(contexts[k])
            match = sequence[1][start.char]
            if match and #after > 0 then
                local prev = start.prev
                if prev then
                    if #after == 1 then
                        match = prev.id == glyph and prev.subtype<256 and prev.font == currentfont and after[1][prev.char]
                    else
                        for n=1,#after do
                            if prev then
                                local id = prev.id
                                if id == glyph and prev.subtype<256 and prev.font == currentfont then -- normal char
                                    local char = prev.char
                                    local class = characters[char].description.class
                                    if class == skipmark or class == skipligature or class == skipbase then
                                        -- skip 'm
                                    elseif not after[n][char] then
                                        match = false break
                                    end
                                elseif id == disc then
                                    -- skip 'm
                                elseif not after[n][32] then
                                    match = false break
                                end
                                prev = prev.prev
                            elseif not after[n][32] then
                                match = false break
                            end
                        end
                    end
                elseif #after == 1 then
                    match = after[1][32]
                else
                    for n=#after,1 do
                        if not after[n][32] then
                            match = false break
                        end
                    end
                end
            end
            if match and #before > 0 then
                local next = stop.next
                if next then
                    if #after == 1 then
                        match = next.id == glyph and next.subtype<256 and next.font == currentfont and before[1][next.char]
                    else
                        for n=#before,1 do
                            if next then
                                local id = next.id
                                if id == glyph and next.subtype<256 and next.font == currentfont then -- normal char
                                    local char = next.char
                                    local class = characters[char].description.class
                                    if class == skipmark or class == skipligature or class == skipbase then
                                        -- skip 'm
                                    elseif not before[n][char] then
                                        match = false break
                                    end
                                elseif id == disc then
                                    -- skip 'm
                                elseif not before[n][32] then -- brrr
                                    match = false break
                                end
                                next = next.next
                            elseif not before[n][32] then
                                match = false break
                            end
                        end
                    end
                elseif #before == 1 then
                    match = before[1][32]
                else
                    for n=1,#before do
                        if not before[n][32] then
                            match = false break
                        end
                    end
                end
            end
            if match then
                local trace = fonts.otf.trace_contexts
                if trace then
                    report("otf reverse chain",format("%s: rule %s of %s matches %s times at char %s (%s) lookuptype %s",kind,rule,lookupname,#sequence,char,utf.char(char),lookuptype))
                end
                if lookups then
                    local cp = chainprocs[lookuptype]
                    if cp then
                        start = cp(start,stop,kind,lookupname,sequence,lookups,flags)
                    else
                        report("otf reverse chain",format("%s: lookuptype %s not supported yet for %s",kind,lookuptype,lookupname))
                    end
                elseif trace then
                    report("otf reverse chain",format("%s: skipping match for %s",kind,lookupname))
                end
                done = true
                break
            end
        end
        return start, done
    end

    fonts.otf.features.process.gsub_context             = fonts.otf.features.process.contextchain
    fonts.otf.features.process.gsub_contextchain        = fonts.otf.features.process.contextchain
    fonts.otf.features.process.gsub_reversecontextchain = fonts.otf.features.process.reversecontextchain

    fonts.otf.features.process.gpos_contextchain        = fonts.otf.features.process.contextchain
    fonts.otf.features.process.gpos_context             = fonts.otf.features.process.contextchain

end

do

    local process = fonts.otf.features.process.feature

    function fonts.methods.node.otf.aalt(head,font,attr) return process(head,font,attr,'aalt') end
    function fonts.methods.node.otf.afrc(head,font,attr) return process(head,font,attr,'afrc') end
    function fonts.methods.node.otf.akhn(head,font,attr) return process(head,font,attr,'akhn') end
    function fonts.methods.node.otf.c2pc(head,font,attr) return process(head,font,attr,'c2pc') end
    function fonts.methods.node.otf.c2sc(head,font,attr) return process(head,font,attr,'c2sc') end
    function fonts.methods.node.otf.calt(head,font,attr) return process(head,font,attr,'calt') end
    function fonts.methods.node.otf.case(head,font,attr) return process(head,font,attr,'case') end
    function fonts.methods.node.otf.ccmp(head,font,attr) return process(head,font,attr,'ccmp') end
    function fonts.methods.node.otf.clig(head,font,attr) return process(head,font,attr,'clig') end
    function fonts.methods.node.otf.cpsp(head,font,attr) return process(head,font,attr,'cpsp') end
    function fonts.methods.node.otf.cswh(head,font,attr) return process(head,font,attr,'cswh') end
    function fonts.methods.node.otf.curs(head,font,attr) return process(head,font,attr,'curs') end
    function fonts.methods.node.otf.dlig(head,font,attr) return process(head,font,attr,'dlig') end
    function fonts.methods.node.otf.dnom(head,font,attr) return process(head,font,attr,'dnom') end
    function fonts.methods.node.otf.expt(head,font,attr) return process(head,font,attr,'expt') end
    function fonts.methods.node.otf.fin2(head,font,attr) return process(head,font,attr,'fin2') end
    function fonts.methods.node.otf.fin3(head,font,attr) return process(head,font,attr,'fin3') end
    function fonts.methods.node.otf.fina(head,font,attr) return process(head,font,attr,'fina',3) end
    function fonts.methods.node.otf.frac(head,font,attr) return process(head,font,attr,'frac') end
    function fonts.methods.node.otf.fwid(head,font,attr) return process(head,font,attr,'fwid') end
    function fonts.methods.node.otf.haln(head,font,attr) return process(head,font,attr,'haln') end
    function fonts.methods.node.otf.hist(head,font,attr) return process(head,font,attr,'hist') end
    function fonts.methods.node.otf.hkna(head,font,attr) return process(head,font,attr,'hkna') end
    function fonts.methods.node.otf.hlig(head,font,attr) return process(head,font,attr,'hlig') end
    function fonts.methods.node.otf.hngl(head,font,attr) return process(head,font,attr,'hngl') end
    function fonts.methods.node.otf.hwid(head,font,attr) return process(head,font,attr,'hwid') end
    function fonts.methods.node.otf.init(head,font,attr) return process(head,font,attr,'init',1) end
    function fonts.methods.node.otf.isol(head,font,attr) return process(head,font,attr,'isol',4) end
    function fonts.methods.node.otf.ital(head,font,attr) return process(head,font,attr,'ital') end
    function fonts.methods.node.otf.jp78(head,font,attr) return process(head,font,attr,'jp78') end
    function fonts.methods.node.otf.jp83(head,font,attr) return process(head,font,attr,'jp83') end
    function fonts.methods.node.otf.jp90(head,font,attr) return process(head,font,attr,'jp90') end
    function fonts.methods.node.otf.kern(head,font,attr) return process(head,font,attr,'kern') end
    function fonts.methods.node.otf.liga(head,font,attr) return process(head,font,attr,'liga') end
    function fonts.methods.node.otf.lnum(head,font,attr) return process(head,font,attr,'lnum') end
    function fonts.methods.node.otf.locl(head,font,attr) return process(head,font,attr,'locl') end
    function fonts.methods.node.otf.mark(head,font,attr) return process(head,font,attr,'mark') end
    function fonts.methods.node.otf.med2(head,font,attr) return process(head,font,attr,'med2') end
    function fonts.methods.node.otf.medi(head,font,attr) return process(head,font,attr,'medi',2) end
    function fonts.methods.node.otf.mgrk(head,font,attr) return process(head,font,attr,'mgrk') end
    function fonts.methods.node.otf.mkmk(head,font,attr) return process(head,font,attr,'mkmk') end
    function fonts.methods.node.otf.nalt(head,font,attr) return process(head,font,attr,'nalt') end
    function fonts.methods.node.otf.nlck(head,font,attr) return process(head,font,attr,'nlck') end
    function fonts.methods.node.otf.nukt(head,font,attr) return process(head,font,attr,'nukt') end
    function fonts.methods.node.otf.numr(head,font,attr) return process(head,font,attr,'numr') end
    function fonts.methods.node.otf.onum(head,font,attr) return process(head,font,attr,'onum') end
    function fonts.methods.node.otf.ordn(head,font,attr) return process(head,font,attr,'ordn') end
    function fonts.methods.node.otf.ornm(head,font,attr) return process(head,font,attr,'ornm') end
    function fonts.methods.node.otf.pnum(head,font,attr) return process(head,font,attr,'pnum') end
    function fonts.methods.node.otf.pref(head,font,attr) return process(head,font,attr,'pref') end
    function fonts.methods.node.otf.pres(head,font,attr) return process(head,font,attr,'pres') end
    function fonts.methods.node.otf.pstf(head,font,attr) return process(head,font,attr,'pstf') end
    function fonts.methods.node.otf.rlig(head,font,attr) return process(head,font,attr,'rlig') end
    function fonts.methods.node.otf.rphf(head,font,attr) return process(head,font,attr,'rphf') end
    function fonts.methods.node.otf.salt(head,font,attr) return process(head,font,attr,'calt') end
    function fonts.methods.node.otf.sinf(head,font,attr) return process(head,font,attr,'sinf') end
    function fonts.methods.node.otf.smcp(head,font,attr) return process(head,font,attr,'smcp') end
    function fonts.methods.node.otf.smpl(head,font,attr) return process(head,font,attr,'smpl') end
    function fonts.methods.node.otf.ss01(head,font,attr) return process(head,font,attr,'ss01') end
    function fonts.methods.node.otf.ss02(head,font,attr) return process(head,font,attr,'ss02') end
    function fonts.methods.node.otf.ss03(head,font,attr) return process(head,font,attr,'ss03') end
    function fonts.methods.node.otf.ss04(head,font,attr) return process(head,font,attr,'ss04') end
    function fonts.methods.node.otf.ss05(head,font,attr) return process(head,font,attr,'ss05') end
    function fonts.methods.node.otf.ss06(head,font,attr) return process(head,font,attr,'ss06') end
    function fonts.methods.node.otf.ss07(head,font,attr) return process(head,font,attr,'ss07') end
    function fonts.methods.node.otf.ss08(head,font,attr) return process(head,font,attr,'ss08') end
    function fonts.methods.node.otf.ss09(head,font,attr) return process(head,font,attr,'ss09') end
    function fonts.methods.node.otf.subs(head,font,attr) return process(head,font,attr,'subs') end
    function fonts.methods.node.otf.sups(head,font,attr) return process(head,font,attr,'sups') end
    function fonts.methods.node.otf.swsh(head,font,attr) return process(head,font,attr,'swsh') end
    function fonts.methods.node.otf.titl(head,font,attr) return process(head,font,attr,'titl') end
    function fonts.methods.node.otf.tnam(head,font,attr) return process(head,font,attr,'tnam') end
    function fonts.methods.node.otf.tnum(head,font,attr) return process(head,font,attr,'tnum') end
    function fonts.methods.node.otf.trad(head,font,attr) return process(head,font,attr,'trad') end
    function fonts.methods.node.otf.unic(head,font,attr) return process(head,font,attr,'unic') end
    function fonts.methods.node.otf.zero(head,font,attr) return process(head,font,attr,'zero') end

end

-- common stuff

function fonts.otf.features.language(tfmdata,value)
    if value then
        value = value:lower()
        if fonts.otf.tables.languages[value] then
            tfmdata.language = value
        end
    end
end

function fonts.otf.features.script(tfmdata,value)
    if value then
        value = value:lower()
        if fonts.otf.tables.scripts[value] then
            tfmdata.script = value
        end
    end
end

function fonts.otf.features.mode(tfmdata,value)
    if value then
        tfmdata.mode = value:lower()
    end
end

fonts.initializers.base.otf.language = fonts.otf.features.language
fonts.initializers.base.otf.script   = fonts.otf.features.script
fonts.initializers.base.otf.mode     = fonts.otf.features.mode
fonts.initializers.base.otf.method   = fonts.otf.features.mode

fonts.initializers.node.otf.language = fonts.otf.features.language
fonts.initializers.node.otf.script   = fonts.otf.features.script
fonts.initializers.node.otf.mode     = fonts.otf.features.mode
fonts.initializers.node.otf.method   = fonts.otf.features.mode

do

    local tlig_list = {
        endash        = "hyphen hyphen",
        emdash        = "hyphen hyphen hyphen",
        quotedblleft  = "quoteleft quoteleft",
        quotedblright = "quoteright quoteright",
        quotedblleft  = "grave grave",
        quotedblright = "quotesingle quotesingle",
        quotedblbase  = "comma comma",
    }
    local trep_list = {
        [0x0022] = 0x201D,
        [0x0027] = 0x2019,
        [0x0060] = 0x2018,
    }

    local tlig_feature = {
        features  = { { scripts = { { script = "DFLT", langs = { "dflt" }, } }, tag = "tlig", comment = "added bij mkiv" }, },
        name      = "ctx_tlig",
        subtables = { { name = "ctx_tlig_1" } },
        type      = "gsub_ligature",
        flags     = { },
        always    = true
    }
    local trep_feature = {
        features  = { { scripts = { { script = "DFLT", langs = { "dflt" }, } }, tag = "trep", comment = "added bij mkiv" }, },
        name      = "ctx_trep",
        subtables = { { name = "ctx_trep_1" } },
        type      = "gsub_single",
        flags     = { },
        always    = true
    }

    function fonts.otf.enhance.enrich(data,filename)
        for index, glyph in pairs(data.glyphs) do
            local l = tlig_list[glyph.name]
            if l then
                local o = glyph.lookups or { }
                o["ctx_tlig_1"] = { { "ligature", l, glyph.name } }
                glyph.lookups = o
            end
            local r = trep_list[glyph.unicode]
            if r then
                local replacement = data.map.map[r]
                if replacement then
                    local o = glyph.lookups or { }
                    o["ctx_trep_1"] = { { "substitution", data.glyphs[replacement].name } } ---
                    glyph.lookups = o
                end
            end
        end
        data.gsub = data.gsub or { }
        logs.report("load otf","enhance: registering tlig feature")
        table.insert(data.gsub,1,table.fastcopy(tlig_feature))
        logs.report("load otf","enhance: registering trep feature")
        table.insert(data.gsub,1,table.fastcopy(trep_feature))
    end

    local prepare = fonts.otf.features.prepare.feature
    local process = fonts.otf.features.process.feature

    fonts.otf.tables.features['tlig'] = 'TeX Ligatures'
    fonts.otf.tables.features['trep'] = 'TeX Replacements'

    function fonts.initializers.node.otf.tlig(tfm,value) return prepare(tfm,'tlig',value) end
    function fonts.initializers.node.otf.trep(tfm,value) return prepare(tfm,'trep',value) end

    function fonts.methods.node.otf.tlig(head,font,attr) return process(head,font,attr,'tlig') end
    function fonts.methods.node.otf.trep(head,font,attr) return process(head,font,attr,'trep') end

    function fonts.initializers.base.otf.tlig(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'tlig',value) end
    function fonts.initializers.base.otf.trep(tfm,value) fonts.otf.features.prepare_base_substitutions(tfm,'trep',value) end

end

-- we need this because fonts can be bugged

-- \definefontfeature[calt][language=nld,script=latn,mode=node,calt=yes,clig=yes,rlig=yes]
-- \definefontfeature[dflt][language=nld,script=latn,mode=node,calt=no, clig=yes,rlig=yes]
-- \definefontfeature[fixd][language=nld,script=latn,mode=node,calt=no, clig=yes,rlig=yes,ignoredrules={44,45,47}]

-- \starttext

-- {\type{dflt:}\font\test=ZapfinoExtraLTPro*dflt at 24pt \test \char57777\char57812 c/o} \endgraf
-- {\type{calt:}\font\test=ZapfinoExtraLTPro*calt at 24pt \test \char57777\char57812 c/o} \endgraf
-- {\type{fixd:}\font\test=ZapfinoExtraLTPro*fixd at 24pt \test \char57777\char57812 c/o} \endgraf

-- \stoptext

--~ table.insert(fonts.triggers,"ignoredrules")

--~ function fonts.initializers.node.otf.ignoredrules(tfmdata,value)
--~     if value then
--~         -- these tests must move !
--~         tfmdata.unique = tfmdata.unique or { }
--~         tfmdata.unique.ignoredrules = tfmdata.unique.ignoredrules or { }
--~         local ignored = tfmdata.unique.ignoredrules
--~         -- value is already ok now
--~         for s in string.gmatch(value:gsub("[{}]","")..",", "%s*(.-),") do
--~             ignored[tonumber(s)] = true
--~         end
--~     end
--~ end

fonts.initializers.base.otf.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.node.otf.equaldigits = fonts.initializers.common.equaldigits

fonts.initializers.base.otf.lineheight  = fonts.initializers.common.lineheight
fonts.initializers.node.otf.lineheight  = fonts.initializers.common.lineheight

fonts.initializers.base.otf.complement  = fonts.initializers.common.complement
fonts.initializers.node.otf.complement  = fonts.initializers.common.complement

fonts.initializers.base.otf.compose     = fonts.initializers.common.compose
fonts.initializers.node.otf.compose     = fonts.initializers.common.compose

-- temp hack, may change

function fonts.initializers.base.otf.kern(tfmdata,value)
    fonts.otf.features.prepare_base_kerns(tfmdata,'kern',value)
end

-- bonus function

function fonts.otf.name_to_slot(name) -- todo: afm en tfm
    local tfmdata = fonts.tfm.id[font.current()]
    if tfmdata and tfmdata.shared then
        local otfdata = tfmdata.shared.otfdata
        if otfdata and otfdata.luatex then
            return otfdata.luatex.unicodes[name]
        end
    end
    return nil
end

function fonts.otf.char(n) -- todo: afm en tfm
    if type(n) == "string" then
        n = fonts.otf.name_to_slot(n)
    end
    if n then
        tex.sprint(tex.ctxcatcodes,string.format("\\char%s ",n))
    end
end

--~ function fonts.otf.name_to_table(name)
--~     lcoal temp, result = { }
--~     local tfmdata = fonts.tfm.id[font.current()]
--~     if tfmdata and tfmdata.shared then
--~         local otfdata = tfmdata.shared.otfdata
--~         if otfdata and otfdata.luatex then
--~             for k,v in pairs(otfdata.glyphs) do
--~                 if v.name:find(name) then
--~                     temp[v.name] = v.unicode
--~                 end
--~             end
--~         end
--~     end
--~     for k,v in pairs(table.sortedkeys(temp)) do
--~         result[#result+1] = { v, temp[v] }
--~     end
--~     return result
--~ end

-- Here we plug in some analyzing code

-- will move to font-tfm

do

    local glyph           = node.id('glyph')
    local glue            = node.id('glue')
    local penalty         = node.id('penalty')

    local fontdata        = fonts.tfm.id
    local set_attribute   = node.set_attribute
    local has_attribute   = node.has_attribute
    local state           = attributes.numbers['state'] or 100

    local fcs             = fonts.color.set
    local fcr             = fonts.color.reset

    -- in the future we will use language/script attributes instead of the
    -- font related value, but then we also need dynamic features which is
    -- somewhat slower; and .. we need a chain of them

    local type = type

    local initializers, methods = fonts.analyzers.initializers, fonts.analyzers.methods

    function fonts.initializers.node.otf.analyze(tfmdata,value,attr)
        if attr and attr > 0 then
            script, language = a_to_script[attr], a_to_language[attr]
        else
            script, language = tfmdata.script, tfmdata.language
        end
        local action = initializers[script]
        if action then
            if type(action) == "function" then
                return action(tfmdata,value)
            else
                local action = action[language]
                if action then
                    return action(tfmdata,value)
                end
            end
        end
        return nil
    end

    function fonts.methods.node.otf.analyze(head,font,attr)
        local tfmdata = fontdata[font]
        local script, language
        if attr and attr > 0 then
            script, language = a_to_script[attr], a_to_language[attr]
        else
            script, language = tfmdata.script, tfmdata.language
        end
        local action = methods[script]
        if action then
            if type(action) == "function" then
                return action(head,font,attr)
            else
                action = action[language]
                if action then
                    return action(head,font,attr)
                end
            end
        end
        return head, false
    end

    fonts.otf.features.register("analyze",true) -- we always analyze
    table.insert(fonts.triggers,"analyze")      -- we need a proper function for doing this

    -- latin

    fonts.analyzers.methods.latn = fonts.analyzers.aux.setstate

    -- arab / todo: 0640 tadwil

    -- this info eventually will go into char-def

    local isol = {
        [0x0621] = true,
    }

    local isol_fina = {
        [0x0622] = true, [0x0623] = true, [0x0624] = true, [0x0625] = true, [0x0627] = true, [0x062F] = true,
        [0x0630] = true, [0x0631] = true, [0x0632] = true,
        [0x0648] = true,
        [0xFEF5] = true, [0xFEF7] = true, [0xFEF9] = true, [0xFEFB] = true,
    }

    local isol_fina_medi_init = {
        [0x0626] = true, [0x0628] = true, [0x0629] = true, [0x062A] = true, [0x062B] = true, [0x062C] = true, [0x062D] = true, [0x062E] = true,
        [0x0633] = true, [0x0634] = true, [0x0635] = true, [0x0636] = true, [0x0637] = true, [0x0638] = true, [0x0639] = true, [0x063A] = true,
        [0x0641] = true, [0x0642] = true, [0x0643] = true, [0x0644] = true, [0x0645] = true, [0x0646] = true, [0x0647] = true, [0x0649] = true, [0x064A] = true,
        [0x067E] = true,
        [0x0686] = true,
    }

    local arab_warned = { }

    local function warning(current,what)
        local char = current.char
        if not arab_warned[char] then
            log.report("analyze",string.format("arab: character %s (0x%04X) has no %s class", char, char, what))
            arab_warned[char] = true
        end
    end

    function fonts.analyzers.methods.nocolor(head,font,attr)
        for n in node.traverse(head,glyph) do
            if not font or n.font == font then
                fcr(n)
            end
        end
        return head, true
    end

    function fonts.analyzers.methods.arab(head,font,attr) -- maybe make a special version with no trace
        local characters = fontdata[font].characters
        local first, last, current, done = nil, nil, head, false
        local trace = fonts.color.trace
    --~ local laststate = 0
        local function finish()
            if last then
                if first == last then
                    if isol_fina_medi_init[first.char] or isol_fina[first.char] then
                        set_attribute(first,state,4) -- isol
                        if trace then fcs(first,"font:isol") end
                    else
                        warning(first,"isol")
                        set_attribute(first,state,0) -- error
                        if trace then fcr(first) end
                    end
                else
                    if isol_fina_medi_init[last.char] or isol_fina[last.char] then -- why isol here ?
                    -- if laststate == 1 or laststate == 2 or laststate == 4 then
                        set_attribute(last,state,3) -- fina
                        if trace then fcs(last,"font:fina") end
                    else
                        warning(last,"fina")
                        set_attribute(last,state,0) -- error
                        if trace then fcr(last) end
                    end
                end
                first, last = nil, nil
            elseif first then
                -- first and last are either both set so we never com here
                if isol_fina_medi_init[first.char] or isol_fina[first.char] then
                    set_attribute(first,state,4) -- isol
                    if trace then fcs(first,"font:isol") end
                else
                    warning(first,"isol")
                    set_attribute(first,state,0) -- error
                    if trace then fcr(first) end
                end
                first = nil
            end
        --~ laststate = 0
        end
        while current do
            if current.id == glyph and current.subtype<256 and current.font == font then
                done = true
                local char = current.char
                local chardata = characters[char]
                if not chardata then
                    -- troubles
                elseif chardata.description.class == "mark" then -- marks are now in components
                    set_attribute(current,state,5) -- mark
                    if trace then fcs(current,"font:mark") end
                elseif isol[char] then
                    finish()
                    set_attribute(current,state,4) -- isol
                    if trace then fcs(current,"font:isol") end
                    first, last = nil, nil
                --~ laststate = 0
                elseif not first then
                    if isol_fina_medi_init[char] then
                        set_attribute(current,state,1) -- init
                        if trace then fcs(current,"font:init") end
                        first, last = first or current, current
                    --~ laststate = 1
                    elseif isol_fina[char] then
                        set_attribute(current,state,4) -- isol
                        if trace then fcs(current,"font:isol") end
                        first, last = nil, nil
                    --~ laststate = 0
                    else -- no arab
                        finish()
                    end
                elseif isol_fina_medi_init[char] then
                    first, last = first or current, current
                    set_attribute(current,state,2) -- medi
                    if trace then fcs(current,"font:medi") end
                    --~ laststate = 2
                elseif isol_fina[char] then
                    -- if not laststate == 1 then
                    if not has_attribute(last,state,1) then
                        -- tricky, we need to check what last may be !
                        set_attribute(last,state,2) -- medi
                        if trace then fcs(last,"font:medi") end
                    end
                    set_attribute(current,state,3) -- fina
                    if trace then fcs(current,"font:fina") end
                    first, last = nil, nil
                --~ laststate = 0
                elseif char >= 0x0600 and char <= 0x06FF then
                    if trace then fcs(current,"font:rest") end
                    finish()
                else --no
                    finish()
                end
            else
                finish()
            end
            current = current.next
        end
        finish()
        return head, done
    end

    -- han (chinese) (unfinished)

    -- this info eventually will go into char-def

    -- in the future we will use language/script attributes instead of the
    -- font related value, but then we also need dynamic features which is
    -- somewhat slower; and .. we need a chain of them

    local type = type

    local opening_parenthesis_hw = table.tohash { -- half width
        0x0028,
        0x005B,
        0x007B,
        0x2018, -- ‘
        0x201C, -- “
    }

    local opening_parenthesis_fw = table.tohash { -- full width
        0x3008, -- 〈   Left book quote
        0x300A, -- 《   Left double book quote
        0x300C, -- 「   left quote
        0x300E, -- 『   left double quote
        0x3010, -- 【   left double book quote
        0x3014, -- 〔   left book quote
        0x3016, --〖   left double book quote
        0x3018, --     left tortoise bracket
        0x301A, --     left square bracket
        0x301D, --     reverse double prime qm
        0xFF08, -- （   left parenthesis
        0xFF3B, -- ［   left square brackets
        0xFF5B, -- ｛   left curve bracket
        0xFF62, --     left corner bracket
    }

    local closing_parenthesis_hw = table.tohash { -- half width
        0x0029,
        0x005D,
        0x007D,
        0x2019, -- ’   right quote, right
        0x201D, -- ”   right double quote
    }

    local closing_parenthesis_fw = table.tohash { -- full width
        0x3009, -- 〉   book quote
        0x300B, -- 》   double book quote
        0x300D, -- 」   right quote, right
        0x300F, -- 』   right double quote
        0x3011, -- 】   right double book quote
        0x3015, -- 〕   right book quote
        0x3017, -- 〗  right double book quote
        0x3019, --     right tortoise bracket
        0x301B, --     right square bracket
        0x301E, --     double prime qm
        0x301F, --     low double prime qm
        0xFF09, -- ）   right parenthesis
        0xFF3D, -- ］   right square brackets
        0xFF5D, -- ｝   right curve brackets
        0xFF63, --     right corner bracket
    }

    local opening_vertical = table.tohash {
        0xFE35, 0xFE37, 0xFE39,  0xFE3B,  0xFE3D,  0xFE3F,  0xFE41,  0xFE43,  0xFE47,
    }

    local closing_vertical = table.tohash {
        0xFE36, 0xFE38, 0xFE3A,  0xFE3C,  0xFE3E,  0xFE40,  0xFE42,  0xFE44,  0xFE48,
    }

    local opening_punctuation_hw = table.tohash { -- half width
    }

    local opening_punctuation_fw = table.tohash {
    --  0x2236, -- ∶
    --  0xFF0C, -- ，
    }

    local closing_punctuation_hw = table.tohash { -- half width
        0x0021, -- !
        0x002C, -- ,
        0x002E, -- .
        0x003A, -- :
        0x003B, -- ;
        0x003F, -- ?
        0xFF61, -- hw full stop
    }

    local closing_punctuation_fw = table.tohash { -- full width
        0x3001, -- 、
        0x3002, -- 。
        0xFF01, -- ！
        0xFF0C, -- ，
        0xFF0E, -- ．
        0xFF1A, -- ：
        0xFF1B, -- ；
        0xFF1F, -- ？
    }

    local non_starter = table.tohash { -- japanese
        0x3005, 0x3041, 0x3043, 0x3045, 0x3047,
        0x3049, 0x3063, 0x3083, 0x3085, 0x3087,
        0x308E, 0x3095, 0x3096, 0x309B, 0x309C,
        0x309D, 0x309E, 0x30A0, 0x30A1, 0x30A3,
        0x30A5, 0x30A7, 0x30A9, 0x30C3, 0x30E3,
        0x30E5, 0x30E7, 0x30EE, 0x30F5, 0x30F6,
        0x30FC, 0x30FD, 0x30FE, 0x31F0, 0x31F1,
        0x30F2, 0x30F3, 0x30F4, 0x31F5, 0x31F6,
        0x30F7, 0x30F8, 0x30F9, 0x31FA, 0x31FB,
        0x30FC, 0x30FD, 0x30FE, 0x31FF,
    }

    -- the characters below are always appear in a double form, so there
    -- will be two Chinese ellipsis characters together that denote
    -- ellipsis marks and it is not allowed to break between them

    local hyphenation = table.tohash {
        0x2026, -- …   ellipsis
        0x2014, -- —   hyphen
    }

    local function is_han_character(char)
        return
            (char>=0x04E00 and char<=0x09FFF) or
            (char>=0x03400 and char<=0x04DFF) or
            (char>=0x20000 and char<=0x2A6DF) or
            (char>=0x0F900 and char<=0x0FAFF) or
            (char>=0x2F800 and char<=0x2FA1F)
    end

    --~ opening_parenthesis_hw / closing_parenthesis_hw
    --~ opening_parenthesis_fw / closing_parenthesis_fw
    --~ opening_punctuation_hw / closing_punctuation_hw
    --~ opening_punctuation_fw / closing_punctuation_fw

    --~ non_starter
    --~ hyphenation

    --~ opening_vertical / closing_vertical

    fonts.analyzers.methods.stretch_hang = true

    fonts.analyzers.methods.hang_data = {
        inter_char_stretch_factor      = 2.00, -- we started with 0.5, then 1.0
        inter_char_half_factor         = 0.50, -- normally there is no reason to change this
        inter_char_half_schrink_factor = 0.25, -- normally there is no reason to change this
    }

    local hang_data = fonts.analyzers.methods.hang_data

    local insert_after, insert_before, delete = node.insert_after, node.insert_before, nodes.delete

    function fonts.analyzers.methods.hang(head,font,attr)
        -- maybe make a special version with no trace
        local characters = fontdata[font].characters
        local current, done, stretch, prevclass = head, false, 0, 0
        if fonts.analyzers.methods.stretch_hang then
            stretch = fontdata[font].parameters[6]
        end
        -- penalty before break
        local interspecialskip   = - stretch * hang_data.inter_char_half_factor
        local interspecialshrink =   stretch * hang_data.inter_char_half_schrink_factor
        local internormalstretch =   stretch * hang_data.inter_char_stretch_factor
        while current do
            if current.id == glyph and current.subtype<256 then
                if current.font == font then
                    local char = current.char
                    if false then
                        -- don't ask -)
                    elseif opening_punctuation_fw[char] or opening_parenthesis_fw[char] then
                        fcs(current,"font:init")
                        head, _ = insert_before(head,current,nodes.glue(interspecialskip,0,interspecialshrink))
                        head, current = insert_after(head,current,nodes.penalty(0))
                        head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        prevclass, done = 1, true
                    elseif closing_punctuation_fw[char] or closing_parenthesis_fw[char] then
                        fcs(current,"font:fina")
                        if prevclass > 0  then
                            local prev = current.prev
                            prev.prev.penalty = 10000
                            head, current = insert_after(head,current,nodes.penalty(10000))
                            head, current = insert_after(head,current,nodes.glue(interspecialskip,0,interspecialshrink))
                            head, current = insert_after(head,current,nodes.penalty(0))
                            head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        end
                        prevclass, done = 2, true
                    elseif opening_punctuation_hw[char] or opening_parenthesis_hw[char] then
                        fcs(current,"font:init")
                        head, current = insert_after(head,current,nodes.penalty(0))
                        head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        prevclass, done = 3, true
                    elseif closing_punctuation_hw[char] or closing_parenthesis_hw[char] then
                        fcs(current,"font:fina")
                        if prevclass > 0  then
                            local prev = current.prev
                            prev.prev.penalty = 10000
                            head, current = insert_after(head,current,nodes.penalty(0))
                            head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        end
                        prevclass, done = 4, true
                    elseif hyphenation[char] then
                        fcs(current,"font:medi")
                        if prevclass > 0  then
                            local prev = current.prev
                            prev.prev.penalty = 10000
                            head, current = insert_after(head,current,nodes.penalty(0))
                            head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        end
                        prevclass, done = 5, true
                    elseif non_starter[char] then
                        fcs(current,"font:isol")
                        head, current = insert_after(head,current,nodes.penalty(10000))
                        head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                        prevclass, done = 6, true
                    elseif is_han_character(char) then
                        prevclass, done = 7, true
                        head, current = insert_after(head,current,nodes.penalty(0))
                        head, current = insert_after(head,current,nodes.glue(0,internormalstretch,0))
                    end
                else
                    prevclass = 0
                end
            elseif prevclass > 0 and current.id == glue and current.spec and current.spec.width > 0 then
                head, current = delete(head,current)
            end
            if current then
                current = current.next
            end
        end
        return head, done
    end

    fonts.analyzers.methods.hani = fonts.analyzers.methods.hang

end

-- experimental and will probably change

do
    local process = fonts.otf.features.process.feature
    local prepare = fonts.otf.features.prepare.feature
    function fonts.install_feature(type,...)
        if fonts[type] and fonts[type].install_feature then
            fonts[type].install_feature(...)
        end
    end
    function fonts.otf.install_feature(tag)
        fonts.methods.node.otf     [tag] = function(head,font,attr) return process(head,font,attr,tag) end
        fonts.initializers.node.otf[tag] = function(tfm,value)      return prepare(tfm,tag,value) end
    end
end
