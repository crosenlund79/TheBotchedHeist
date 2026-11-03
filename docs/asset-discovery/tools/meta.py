# Visual identification of every POLYGON Heist prefab, written after reviewing each rendered preview.
# name -> (category, represents, heist_use, completeness, confidence)
# completeness: "Complete" | "Component" | "Modular piece"
C, K, M = "Complete", "Component", "Modular piece"
CONF, PROB, UNK = "Confirmed", "Probable", "Unknown"

META = {
# ---------------- Characters ----------------
"SM_Chr_Female_FBI_01": ("Characters", "Female FBI agent: blue 'FBI' vest, shirt, holster", "Federal agent NPC / responding law enforcement", C, CONF),
"SM_Chr_Female_Overall_01": ("Characters", "Female in green work overalls with backpack straps", "Heist crew member disguised as maintenance/janitor", C, CONF),
"SM_Chr_Female_Shirt_01": ("Characters", "Female civilian, white shirt, tie, jeans", "Bank customer / hostage / civilian NPC; crew in plain clothes", C, CONF),
"SM_Chr_Female_SuitVest_01": ("Characters", "Female in business suit, vest and skirt", "Bank manager / teller / office worker NPC", C, CONF),
"SM_Chr_Male_FBI_01": ("Characters", "Male FBI agent: blue 'FBI' vest, sunglasses", "Federal agent NPC / responding law enforcement", C, CONF),
"SM_Chr_Male_Overall_01": ("Characters", "Male in green work overalls", "Heist crew member disguised as maintenance", C, CONF),
"SM_Chr_Male_SWAT_01": ("Characters", "SWAT officer: black armour, helmet, goggles, balaclava", "Main armed enemy / tactical police", C, CONF),
"SM_Chr_Male_Shirt_01": ("Characters", "Male civilian, white shirt, tie, jeans, sunglasses", "Civilian / hostage / player base body under masks", C, CONF),
"SM_Chr_Male_SuitVest_01": ("Characters", "Male in suit and waistcoat, sunglasses", "Bank manager, security chief, or crew 'face'", C, CONF),
# ---------------- Masks & Hair ----------------
"SM_Item_Hair_Eyebrow_Man_01": ("Masks & Hair", "Male eyebrows mesh", "Head attachment used by male character prefabs", K, CONF),
"SM_Item_Hair_Eyebrow_Woman_01": ("Masks & Hair", "Female eyebrows mesh", "Head attachment used by female character prefabs", K, CONF),
"SM_Item_Hair_Man_01": ("Masks & Hair", "Short male hairstyle", "Head attachment; hide when a mask is worn", K, CONF),
"SM_Item_Hair_Woman_01": ("Masks & Hair", "Female hairstyle with bun", "Head attachment; hide when a mask is worn", K, CONF),
"SM_Item_Mask_Alien_01": ("Masks & Hair", "Alien face mask (pale green, large black eyes)", "Robber disguise / cosmetic unlock", C, CONF),
"SM_Item_Mask_Balaclava_01": ("Masks & Hair", "Black balaclava", "Classic robber disguise", C, CONF),
"SM_Item_Mask_Beanie_01": ("Masks & Hair", "Green beanie over dark face covering", "Robber disguise", C, CONF),
"SM_Item_Mask_Chicken_01": ("Masks & Hair", "Rooster / chicken head mask", "Comedic robber disguise", C, CONF),
"SM_Item_Mask_Clown_01": ("Masks & Hair", "Clown mask with purple hair tuft", "Robber disguise", C, CONF),
"SM_Item_Mask_Construction_01": ("Masks & Hair", "Yellow hard hat with dust mask", "Worker disguise", C, CONF),
"SM_Item_Mask_Fox_01": ("Masks & Hair", "Fox face mask", "Robber disguise", C, CONF),
"SM_Item_Mask_Gas_01": ("Masks & Hair", "Gas mask with blue lenses", "Tear-gas protection / robber disguise", C, CONF),
"SM_Item_Mask_Glasses_01": ("Masks & Hair", "Novelty glasses with fake nose and moustache", "Comedic disguise", C, CONF),
"SM_Item_Mask_Hat_01": ("Masks & Hair", "Red baseball cap with skull face covering", "Robber disguise", C, CONF),
"SM_Item_Mask_Hockey_01": ("Masks & Hair", "White hockey goalie mask", "Robber disguise", C, CONF),
"SM_Item_Mask_Horse_01": ("Masks & Hair", "Horse head mask", "Comedic robber disguise", C, CONF),
"SM_Item_Mask_Luchador_01": ("Masks & Hair", "Luchador wrestling mask (green/orange)", "Robber disguise", C, CONF),
"SM_Item_Mask_Panda_01": ("Masks & Hair", "Panda head mask", "Robber disguise", C, CONF),
"SM_Item_Mask_PaperBag_01": ("Masks & Hair", "Paper bag with drawn grin", "Cheap improvised disguise", C, CONF),
"SM_Item_Mask_Simple_Man_01": ("Masks & Hair", "Blocky cube-head mask, male face, blond hair", "Disguise; uses SimplePeople mask texture (texture swaps available)", C, CONF),
"SM_Item_Mask_Simple_Robber_01": ("Masks & Hair", "Blocky cube-head mask with blue robber eye-band", "Disguise", C, CONF),
"SM_Item_Mask_Simple_Woman_01": ("Masks & Hair", "Blocky cube-head mask, female face, blonde hair", "Disguise", C, CONF),
"SM_Item_Mask_Tiger_01": ("Masks & Hair", "Tiger head mask", "Robber disguise", C, CONF),
"SM_Item_Mask_Trump_01": ("Masks & Hair", "Caricature mask of a real politician (Donald Trump)", "Disguise. Real-person likeness: review before shipping", C, CONF),
"SM_Item_Mask_WeldersMask_01": ("Masks & Hair", "Welder's helmet", "Disguise / thermal-cutting tool flavour", C, CONF),
# ---------------- Items & Tools ----------------
"SM_Item_AmmoPack_01": ("Items & Tools", "Yellow ammo crate with bullets; separate lid and supplies parts", "Ammo resupply pickup (lid can be opened)", C, CONF),
"SM_Item_AmmoPack_02": ("Items & Tools", "Yellow ammo crate, single-piece version", "Ammo resupply pickup (static)", C, CONF),
"SM_Item_Bomb_01": ("Items & Tools", "Improvised explosive: red canister, charges and detonator radio", "Breaching charge / C4 for vault or wall", C, CONF),
"SM_Item_Briefcase_01": ("Items & Tools", "Briefcase with separate lid and money insert", "Loot container; open to reveal cash", C, CONF),
"SM_Item_Briefcase_02": ("Items & Tools", "Closed briefcase, single piece", "Carryable objective / ransom case", C, CONF),
"SM_Item_Crowbar_01": ("Items & Tools", "Orange crowbar", "Pry open doors, boxes and deposit boxes", C, CONF),
"SM_Item_DuffleBag_01": ("Items & Tools", "Duffel bag, closed, red/grey", "Loot bag (carry/throw mechanic)", C, CONF),
"SM_Item_DuffleBag_Empty_01": ("Items & Tools", "Duffel bag, closed, deflated (empty)", "Empty loot bag state", C, CONF),
"SM_Item_DuffleBag_Full_01": ("Items & Tools", "Duffel bag, bulging with cash visible", "Full loot bag state", C, CONF),
"SM_Item_DuffleBag_Open_Empty_01": ("Items & Tools", "Open, empty duffel bag", "Bag placed for filling", C, CONF),
"SM_Item_DuffleBag_Open_Full_01": ("Items & Tools", "Open duffel bag full of cash", "Loot bag / secured loot", C, CONF),
"SM_Item_Hacksaw_01": ("Items & Tools", "Hacksaw", "Cut bars, locks, chains", C, CONF),
"SM_Item_Hammer_01": ("Items & Tools", "Claw hammer", "Tool / melee / smash glass", C, CONF),
"SM_Item_Handcuffs_01": ("Items & Tools", "Handcuffs", "Restrain guards, or police arrest state", C, CONF),
"SM_Item_HealthKit_01": ("Items & Tools", "First-aid case with separate lid and supplies", "Health pickup (openable)", C, CONF),
"SM_Item_HealthKit_02": ("Items & Tools", "First-aid case, single piece", "Health pickup (static)", C, CONF),
"SM_Item_Mallet_01": ("Items & Tools", "Sledgehammer / mallet", "Smash display cases, breach", C, CONF),
"SM_Item_Pouch_01": ("Items & Tools", "Grey utility pouch with straps", "Gear/belt pouch, small loot or tool pickup", C, PROB),
"SM_Item_Rope_01": ("Items & Tools", "Coiled rope", "Rappel / tie hostages", C, CONF),
"SM_Item_ScrewDriver_01": ("Items & Tools", "Screwdriver", "Open vents / panels", C, CONF),
"SM_Item_WalkieTalkie_01": ("Items & Tools", "Walkie-talkie radio", "Crew comms, guard radio, pager-style mechanic", C, CONF),
"SM_Item_Wirecutter_01": ("Items & Tools", "Wire cutters / pliers", "Cut alarm wires, fences", C, CONF),
"SM_Item_Wrench_01": ("Items & Tools", "Adjustable wrench", "Tool pickup", C, CONF),
"SM_Item_ZipTies_01": ("Items & Tools", "Cable / zip tie", "Restrain hostages", C, CONF),
"SM_Prop_Drill_01": ("Items & Tools", "Heavy thermal/vault drill on stand", "Timed vault-drilling objective", C, CONF),
# ---------------- Loot ----------------
"SM_Prop_GoldBar_01": ("Loot & Valuables", "Gold bar (stamped top)", "High-value loot", C, CONF),
"SM_Prop_GoldBar_02": ("Loot & Valuables", "Gold bar (plain)", "High-value loot", C, CONF),
"SM_Prop_Jewellery_01": ("Loot & Valuables", "Jewellery stand with many hanging necklaces/pendants", "Jewellery-store loot display", C, CONF),
"SM_Prop_Jewellery_02": ("Loot & Valuables", "Jewellery stand, fewer items (variant)", "Loot display variant", C, CONF),
"SM_Prop_Jewellery_03": ("Loot & Valuables", "Jewellery stand, sparse (variant)", "Loot display variant / partly looted", C, CONF),
"SM_Prop_Jewellery_04": ("Loot & Valuables", "Long white tray with gold chain strips", "Bracelet/chain display tray", C, PROB),
"SM_Prop_Jewellery_Necklace_01": ("Loot & Valuables", "White bust with gold necklace and purple pendant", "Necklace display loot", C, CONF),
"SM_Prop_Jewellery_Necklace_02": ("Loot & Valuables", "Black bust with ruby necklace", "Necklace display loot", C, CONF),
"SM_Prop_Jewellery_Necklace_03": ("Loot & Valuables", "White bust with gold necklace (variant)", "Necklace display loot", C, CONF),
"SM_Prop_Jewellery_Necklace_04": ("Loot & Valuables", "Black bust with diamond necklace", "Necklace display loot", C, CONF),
"SM_Prop_Jewellery_Ring_01": ("Loot & Valuables", "Ring box / cushion with single ruby ring", "Small loot item", C, CONF),
"SM_Prop_Jewellery_Rings_01": ("Loot & Valuables", "Ring display tray with many gold rings", "Small loot display", C, CONF),
"SM_Prop_Money_Note_01": ("Loot & Valuables", "Single bank note, folded", "Loose cash / pickup VFX", C, CONF),
"SM_Prop_Money_Note_02": ("Loot & Valuables", "Single bank note, flat", "Loose cash", C, CONF),
"SM_Prop_Money_Note_03": ("Loot & Valuables", "Two banded bundles of notes", "Cash bundle", C, CONF),
"SM_Prop_Money_Note_04": ("Loot & Valuables", "Banded cash bundle (thicker)", "Cash bundle", C, CONF),
"SM_Prop_Money_Note_05": ("Loot & Valuables", "Banded cash bundle (variant)", "Cash bundle", C, CONF),
"SM_Prop_Money_Note_06": ("Loot & Valuables", "Banded cash bundle (variant)", "Cash bundle", C, CONF),
"SM_Prop_Money_Note_07": ("Loot & Valuables", "Thick single-band cash brick", "Cash brick", C, CONF),
"SM_Prop_Money_Roll_01": ("Loot & Valuables", "Rolled cash bundle", "Cash pickup", C, CONF),
"SM_Prop_Money_Roll_02": ("Loot & Valuables", "Rolled cash with band", "Cash pickup", C, CONF),
"SM_Prop_Money_Stack_01": ("Loot & Valuables", "Large neat pallet-style cash stack", "Vault cash pile (major loot)", C, CONF),
"SM_Prop_Money_Stack_02": ("Loot & Valuables", "Large cash stack, partially taken", "Vault cash pile, partly looted", C, CONF),
"SM_Prop_Money_Stack_03": ("Loot & Valuables", "Messy pile of cash bundles", "Loose cash heap", C, CONF),
"SM_Prop_VaultTrolley_01": ("Loot & Valuables", "Metal vault / bank trolley cart", "Carry loot from the vault", C, CONF),
# ---------------- Security & Bank fixtures ----------------
"SM_Prop_ATM_01": ("Security & Bank", "ATM cash machine", "Hack / break open for cash; lobby dressing", C, CONF),
"SM_Prop_AlarmButton_01": ("Security & Bank", "Red panic button on yellow/black plate", "Silent alarm trigger for tellers", C, CONF),
"SM_Prop_Camera_01": ("Security & Bank", "CCTV security camera with separate head", "Stealth detection cone; head can pan", C, CONF),
"SM_Prop_MetalDetector_01": ("Security & Bank", "Walk-through metal detector arch", "Entrance security checkpoint", C, CONF),
"SM_Prop_MetalDetector_Baggage_01": ("Security & Bank", "Baggage X-ray scanner with monitor", "Entrance security / smuggling gear", C, CONF),
"SM_Prop_SafeDepositBox_Container_01": ("Security & Bank", "Safe-deposit box drawer with lid", "Openable loot container", C, CONF),
"SM_Prop_SafeDepositBox_Container_02": ("Security & Bank", "Safe-deposit box drawer, shorter, with lid", "Openable loot container", C, CONF),
"SM_Prop_SafeDepositBox_Cover_01": ("Security & Bank", "Safe-deposit box front cover (large)", "Door panel of a deposit box", K, CONF),
"SM_Prop_SafeDepositBox_Cover_02": ("Security & Bank", "Safe-deposit box front cover (keyhole/arrows)", "Door panel of a deposit box", K, CONF),
"SM_Prop_SafeDepositBox_Cover_03": ("Security & Bank", "Safe-deposit box cover with yellow keypad/lock", "Lockable deposit box panel", K, CONF),
"SM_Prop_SafeDepositBoxes_01": ("Security & Bank", "Full wall of safe-deposit boxes", "Vault wall loot (pick boxes)", C, CONF),
"SM_Prop_SafeDepositBoxes_Empty_01": ("Security & Bank", "Deposit-box wall with every box removed", "Fully looted state", C, CONF),
"SM_Prop_SafeDepositBoxes_Half_01": ("Security & Bank", "Deposit-box wall, some boxes removed", "Partly looted state", C, CONF),
"SM_Prop_SafeDepositBoxes_Looted_01": ("Security & Bank", "Deposit-box wall with boxes ripped out and scattered", "Ransacked state", C, CONF),
"SM_Prop_TellerDesk_01": ("Security & Bank", "Teller counter, straight section", "Bank lobby counter", M, CONF),
"SM_Prop_TellerDesk_02": ("Security & Bank", "Teller counter, end/return section", "Bank lobby counter", M, CONF),
"SM_Prop_TellerDesk_03": ("Security & Bank", "Teller counter, narrow column section", "Bank lobby counter", M, CONF),
"SM_Prop_TellerDesk_Barrier_01": ("Security & Bank", "Teller glass screen with cash slot", "Counter security glass", K, CONF),
"SM_Prop_TellerDesk_Barrier_02": ("Security & Bank", "Teller glass screen, plain", "Counter security glass", K, CONF),
"SM_Prop_DisplayCase_01": ("Security & Bank", "Jewellery counter display case; intact + hidden broken glass", "Smash-and-grab loot case (toggle broken glass)", C, CONF),
"SM_Prop_DisplayCase_02": ("Security & Bank", "Glass display cube; intact + hidden broken glass", "Smash-and-grab pedestal case", C, CONF),
"SM_Prop_Glass_Shard_01": ("Security & Bank", "Triangular glass shard", "Debris after smashing glass", K, CONF),
"SM_Prop_Glass_Shard_02": ("Security & Bank", "Flat glass shard", "Debris after smashing glass", K, CONF),
"SM_Prop_Fire_Detector_01": ("Security & Bank", "Ceiling smoke / fire detector disc", "Ceiling dressing; trigger for fire alarm/sprinklers", C, PROB),
"SM_Prop_Sprinkler_01": ("Security & Bank", "Ceiling fire sprinkler head", "Ceiling dressing; sprinkler event", C, PROB),
"SM_Prop_RopeBarrier_01": ("Security & Bank", "Red queue rope, slack", "Queue line between posts", K, CONF),
"SM_Prop_RopeBarrier_02": ("Security & Bank", "Red queue rope, hanging U-shape", "Queue line between posts", K, CONF),
"SM_Prop_RopeBarrier_03": ("Security & Bank", "Straight dark barrier bar/strap", "Queue barrier between posts", K, PROB),
"SM_Prop_RopeBarrier_Pole_01": ("Security & Bank", "Gold queue stanchion post", "Queue barrier post", K, CONF),
"SM_Prop_RopeBarrier_Pole_02": ("Security & Bank", "Black queue stanchion post", "Queue barrier post", K, CONF),
# ---------------- Furniture & Office ----------------
"SM_Prop_AirVent_01": ("Furniture & Office", "Wall air-vent grille", "Stealth entry point / dressing", C, CONF),
"SM_Prop_Aircon_01": ("Furniture & Office", "Wall-mounted split air conditioner", "Wall dressing", C, CONF),
"SM_Prop_Bin_01": ("Furniture & Office", "Office waste bin", "Dressing / hide small items", C, CONF),
"SM_Prop_Box_01": ("Furniture & Office", "Archive / file box with separate lid", "Searchable container", C, CONF),
"SM_Prop_CoffeTable_01": ("Furniture & Office", "Glass coffee table", "Lobby furniture", C, CONF),
"SM_Prop_CoffeeTable_02": ("Furniture & Office", "Octagonal side table", "Lobby furniture", C, CONF),
"SM_Prop_Computer_01": ("Furniture & Office", "Desktop set: monitor, keyboard, mouse", "Hackable terminal (camera loop, door unlock)", C, CONF),
"SM_Prop_Computer_Keyboard_01": ("Furniture & Office", "Computer keyboard", "Desk dressing", K, CONF),
"SM_Prop_Computer_Mouse_01": ("Furniture & Office", "Computer mouse", "Desk dressing", K, PROB),
"SM_Prop_Computer_Screen_01": ("Furniture & Office", "Flat computer monitor", "Desk dressing / security monitor", K, CONF),
"SM_Prop_Couch_01": ("Furniture & Office", "Blue armchair", "Lobby seating / cover", C, CONF),
"SM_Prop_Couch_02": ("Furniture & Office", "Blue two-seat sofa", "Lobby seating / cover", C, CONF),
"SM_Prop_DeskLight_01": ("Furniture & Office", "Green banker's desk lamp", "Office dressing", C, CONF),
"SM_Prop_Desk_01": ("Furniture & Office", "Curved reception desk with glass top piece", "Reception / front desk", C, CONF),
"SM_Prop_Desk_02": ("Furniture & Office", "Office desk, straight", "Office furniture / cover", C, CONF),
"SM_Prop_Desk_03": ("Furniture & Office", "Office desk, L-shaped", "Office furniture / cover", C, CONF),
"SM_Prop_Drawers_01": ("Furniture & Office", "Three-drawer filing cabinet", "Searchable container (keycards, codes)", C, CONF),
"SM_Prop_Folder_01": ("Furniture & Office", "Closed manila folder", "Intel / documents pickup", C, CONF),
"SM_Prop_Folder_02": ("Furniture & Office", "Manila folder with paper edge", "Intel pickup", C, CONF),
"SM_Prop_Folder_03": ("Furniture & Office", "Open folder with loose papers", "Intel pickup (vault codes)", C, CONF),
"SM_Prop_Folder_04": ("Furniture & Office", "Single sheet of paper", "Note / blueprint pickup", C, PROB),
"SM_Prop_Folder_05": ("Furniture & Office", "Blue ring binder", "Shelf dressing / intel", C, CONF),
"SM_Prop_Seat_01": ("Furniture & Office", "Office swivel chair", "Office furniture", C, CONF),
"SM_Prop_Seat_02": ("Furniture & Office", "Waiting-room chair", "Lobby seating", C, CONF),
"SM_Prop_Shelf_01": ("Furniture & Office", "Wooden bookshelf", "Office furniture", C, CONF),
"SM_Prop_Table_01": ("Furniture & Office", "Glass-top table with white frame", "Meeting/lobby table", C, CONF),
"SM_Prop_Table_02": ("Furniture & Office", "Grey metal/vault table with yellow trim", "Vault counting table", C, PROB),
"SM_Prop_WaterCooler_01": ("Furniture & Office", "Water cooler with separate bottle", "Office dressing", C, CONF),
# ---------------- Decor & Signage ----------------
"SM_Prop_Flag_Pole_01": ("Decor & Signage", "US flag on standing pole", "Lobby/government decor", C, CONF),
"SM_Prop_Flag_Straight_01": ("Decor & Signage", "US flag lying flat", "Decor", C, CONF),
"SM_Prop_Flag_Wall_01": ("Decor & Signage", "US flag on angled wall pole", "Facade decor", C, CONF),
"SM_Prop_Flag_Wall_02": ("Decor & Signage", "US flag on angled wall pole (variant)", "Facade decor", C, CONF),
"SM_Prop_Pillar_01": ("Decor & Signage", "Decorative pedestal / plinth with panel", "Statue/display plinth", C, CONF),
"SM_Prop_Pillar_02": ("Decor & Signage", "Plain pedestal / plinth", "Display plinth", C, CONF),
"SM_Prop_Plant_01": ("Decor & Signage", "Potted palm", "Lobby decor", C, CONF),
"SM_Prop_Plant_02": ("Decor & Signage", "Planter box with tall grass", "Lobby decor / low cover", C, CONF),
"SM_Prop_Plant_03": ("Decor & Signage", "Small potted plant", "Decor", C, CONF),
"SM_Prop_Rug_01": ("Decor & Signage", "Red rug with border", "Floor decor", C, CONF),
"SM_Prop_Rug_02": ("Decor & Signage", "Red runner rug (variant)", "Floor decor", C, CONF),
"SM_Prop_Sign_Bank_01": ("Decor & Signage", "3D gold letters 'BANK'", "Facade sign", C, CONF),
"SM_Prop_Sign_Base_01": ("Decor & Signage", "Blank sign backing plate", "Mount for 3D letter signs", K, PROB),
"SM_Prop_Sign_Jewellery_01": ("Decor & Signage", "3D gold letters 'JEWELLERY'", "Facade sign for jewellery store", C, CONF),
"SM_Prop_Sign_Money_Bank_01": ("Decor & Signage", "3D gold letters 'MONEY BANK'", "Facade sign", C, CONF),
"SM_Prop_Statue_01": ("Decor & Signage", "White marble bust / statue", "Lobby decor / art loot", C, CONF),
# ---------------- Vehicles ----------------
"SM_Veh_Car_Police_Heist_01": ("Vehicles", "Police cruiser, separate wheels, glass, plates, steering wheel", "Police response / roadblock / getaway target", C, CONF),
"SM_Veh_Helicopter_01": ("Vehicles", "Light helicopter, separate main/tail rotors, glass, controls", "Police air support or rooftop escape", C, CONF),
"SM_Veh_SwatVan_01": ("Vehicles", "Armoured SWAT van, separate rear doors, wheels, glass", "SWAT deployment point", C, CONF),
# ---------------- Weapons ----------------
"SM_Wep_PistolBandit_01": ("Weapons", "M1911-style pistol (silver, wood grip); separate mag/slide/trigger", "Crew sidearm", C, CONF),
"SM_Wep_PistolSwat_01": ("Weapons", "Glock-style polymer pistol; separate mag/slide/trigger", "Police sidearm", C, CONF),
"SM_Wep_RifleBandit_01": ("Weapons", "AK-style assault rifle; separate mag/slide/trigger", "Crew rifle", C, CONF),
"SM_Wep_RifleSwat_01": ("Weapons", "M4-style carbine; separate charge handle/mag/stock", "SWAT rifle", C, CONF),
"SM_Wep_SMG_01": ("Weapons", "MP5-style SMG; separate mag/slide/trigger", "SWAT/crew SMG", C, CONF),
"SM_Wep_Shotgun_01": ("Weapons", "Pump-action shotgun; separate pump", "Breaching / close range", C, CONF),
"SM_Wep_SniperSwat_01": ("Weapons", "Bolt-action sniper rifle (olive); separate bolt/mag", "Police sniper", C, CONF),
"SM_Wep_Flashbang_Base_01": ("Weapons", "Flashbang grenade with separate clip and pin", "SWAT throwable / crew tool", C, CONF),
"SM_Wep_Grenade_Base_01": ("Weapons", "Frag/smoke grenade with separate clip and pin", "Throwable", C, CONF),
"SM_Wep_Holster_01": ("Weapons", "Pistol holster", "Character gear", K, CONF),
"SM_Wep_Ammo_BulletLarge_01": ("Weapons", "Large bullet (low detail, lying)", "Ammo pickup / shell casing", K, PROB),
"SM_Wep_Ammo_BulletLarge_02": ("Weapons", "Rifle cartridge, upright", "Ammo pickup / casing", K, CONF),
"SM_Wep_Ammo_BulletSmall_01": ("Weapons", "Small bullet (low detail, lying)", "Ammo pickup / casing", K, PROB),
"SM_Wep_Ammo_BulletSmall_02": ("Weapons", "Pistol cartridge, upright", "Ammo pickup / casing", K, CONF),
"SM_Wep_Ammo_Shotgun_01": ("Weapons", "Red shotgun shell", "Ammo pickup / casing", K, CONF),
"SM_Wep_Attachment_Grip_01": ("Weapons", "Vertical foregrip", "Weapon attachment", K, CONF),
"SM_Wep_Attachment_M4Rail_01": ("Weapons", "Picatinny / carry-handle rail", "Weapon attachment", K, PROB),
"SM_Wep_Attachment_Redot_01": ("Weapons", "Red-dot / holographic sight", "Weapon attachment", K, CONF),
"SM_Wep_Attachment_Silencer_01": ("Weapons", "Suppressor", "Stealth weapon attachment", K, CONF),
"SM_Wep_Attachment_SniperScope_01": ("Weapons", "Sniper scope", "Weapon attachment", K, CONF),
"SM_Wep_Attachment_Torch_01": ("Weapons", "Weapon-mounted flashlight", "Weapon attachment", K, CONF),
"SM_Wep_Crosshair_01": ("HUD Crosshairs", "Red dot reticle (emissive mesh)", "In-world reticle for red-dot sight", K, CONF),
"SM_Wep_Crosshair_02": ("HUD Crosshairs", "Red octagon reticle (emissive mesh)", "Sight reticle", K, CONF),
"SM_Wep_Crosshair_03": ("HUD Crosshairs", "Red chevron reticle (emissive mesh)", "Sight reticle", K, CONF),
"SM_Wep_Crosshair_04": ("HUD Crosshairs", "Red cross reticle (emissive mesh)", "Sight reticle", K, CONF),
"SM_Wep_Crosshair_05": ("HUD Crosshairs", "Red octagon with centre dot (emissive mesh)", "Sight reticle", K, CONF),
"SM_Wep_Crosshair_Sniper_01": ("HUD Crosshairs", "Sniper scope reticle ring", "Scope overlay mesh", K, CONF),
}

ENV_META = {
"Ceiling_01": "Ceiling tile slab", "Ceiling_02": "Ceiling slab, edge trim variant", "Ceiling_03": "Ceiling slab, edge trim variant",
"Ceiling_04": "Ceiling slab, edge variant", "Ceiling_05": "Ceiling slab, notched edge", "Ceiling_06": "Ceiling slab, plain",
"Ceiling_07": "Ceiling slab with dark trim strips", "Ceiling_08": "Ceiling panel with recessed frame (light/vent bay)",
"Ceiling_Light_01": "Flush ceiling light panel (emissive)", "Ceiling_Light_02": "Round dome ceiling light (emissive)",
"Ceiling_Light_03": "Pendant light on rod",
"Door_01": "Glass door with frame", "Door_02": "Glass door with frame (variant)", "Door_03": "White interior door",
"Floor_01": "Black-and-white checkered floor tile", "Floor_02": "Salmon/terracotta textured floor tile",
"Pillar_01": "Square column with dark cap and base", "Pillar_02": "Square column, light",
"Railing_01": "Glass balustrade railing", "Road_01": "Road tile with lane markings", "Roof_01": "Roof slab with parapet trims",
"Roof_02": "Roof slab with trims (edge variant)", "Roof_03": "Roof slab (edge variant)", "Roof_04": "Roof slab (corner variant)",
"Roof_05": "Thick plain roof slab", "Sidewalk_01": "Sidewalk tile", "Sidewalk_Straight_01": "Sidewalk tile, straight kerb edge",
"Skylight_01": "Skylight frame with glass", "Stairway_01": "Full staircase", "Steps_01": "Short step block",
"Steps_02": "Step block with gold nosing strips", "Steps_03": "Step block with gold nosing (variant)", "Steps_04": "Step block, plain",
"Steps_Edge_01": "Step edge / kerb piece",
"VaultDoor_Frame_01": "Round bank vault door in wall frame; lid, handles separate and hinged",
"VaultGate_Door_01": "Barred vault gate door", "VaultGate_Frame_01": "Barred vault gate frame sections",
"VaultGate_Wall_01": "Barred vault gate wall section",
"Wall_Window_Blinds_01": "Window blinds insert (pair)", "Wall_Window_Panels_01": "Window louvre panel insert (pair)",
}

def classify(name):
    if name in META:
        return META[name]
    short = name.replace("SM_Env_", "")
    rep = ENV_META.get(short)
    if rep is None:
        # Wall kit
        rep = short.replace("_", " ")
        kind = "Interior" if "Interior" in short else ("Exterior" if "Exterior" in short else ("Glass" if "Glass" in short else ""))
        parts = []
        if "DoubleDoor" in short: parts.append("double-door opening")
        elif "Door" in short: parts.append("single doorway")
        if "Window" in short: parts.append("windows")
        if "Ground" in short: parts.append("ground-floor skirting")
        if "Alt" in short: parts.append("alternate trim")
        desc = {"Interior": "Interior wall panel (grey trim)", "Exterior": "Exterior facade wall panel (stone skirting)", "Glass": "Glass curtain-wall panel"}.get(kind, "Wall panel")
        rep = desc + (": " + ", ".join(parts) if parts else ", solid")
    if short.startswith("Wall") or short.startswith("VaultGate") or short.startswith("Pillar"):
        sub = "Walls & Pillars"
    elif short.startswith(("Floor", "Ceiling", "Roof", "Skylight")):
        sub = "Floors, Ceilings & Roof"
    elif short.startswith(("Stair", "Step", "Railing")):
        sub = "Stairs & Railings"
    elif short.startswith(("Road", "Sidewalk")):
        sub = "Street"
    elif short.startswith(("Door", "VaultDoor")):
        sub = "Doors & Vault"
    else:
        sub = "Building Kit"
    use = {
        "Walls & Pillars": "Modular level geometry (snaps on a grid)",
        "Floors, Ceilings & Roof": "Modular level geometry",
        "Stairs & Railings": "Vertical traversal / level geometry",
        "Street": "Exterior street for getaway / approach",
        "Doors & Vault": "Lockable doors, the vault objective",
    }.get(sub, "Level geometry")
    if "Vault" in short: use = "Vault objective: locked gate/door to breach"
    if "Ceiling_Light" in short: use = "Light fixture: pair with an OmniLight3D/SpotLight3D"
    comp = K if short in ("Wall_Window_Blinds_01", "Wall_Window_Panels_01", "VaultGate_Frame_01") else M
    if short in ("VaultDoor_Frame_01", "Stairway_01", "Door_01", "Door_02", "Door_03"): comp = C
    return ("Building Kit / " + sub, rep, use, comp, CONF if short not in ("Ceiling_Light_01", "Ceiling_08", "Steps_Edge_01") else PROB)
