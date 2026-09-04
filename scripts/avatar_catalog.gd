class_name AvatarCatalog
extends RefCounted

const GENDERS := ["Male", "Female"]
const AGES := ["Liddle", "Young", "Adult", "Old"]
const BUILDS := ["Thin", "Average", "Fat"]
const CHEST_SIZES := ["Small", "Standard", "Large"]

# Every cosmetic is deliberately shared by every gender, age and build.
const HAIRS := [
	"Afro", "Buzz Cut", "Short Crop", "Side Part", "Undercut", "Pompadour",
	"Mohawk", "Faux Hawk", "Messy", "Spikes", "Curly", "Wavy", "Bob",
	"Long Straight", "Long Wavy", "Ponytail", "High Ponytail", "Twin Tails",
	"Braids", "Long Braids", "Bun", "Double Bun", "Mullet", "Bald"
]
const OUTFITS := [
	"Classic Shirt", "T-Shirt", "Tank Top", "Polo", "Hoodie", "Sweater",
	"Cardigan", "Jacket", "Leather Jacket", "Denim Jacket", "Vest", "Suit",
	"Dress", "Tunic", "Overalls", "Tracksuit", "Explorer", "Farmer",
	"Knight", "Wizard", "Pirate", "Ninja", "Royal", "Winter Coat"
]
const CAPES := [
	"None", "Classic", "Short", "Long", "Split", "Royal", "Traveler", "Ragged",
	"Feathered", "Dragon", "Moon", "Sun", "Forest", "Ocean", "Flame", "Frost",
	"Shadow", "Hero", "Villain", "Banner", "HighCraft"
]
const HOODS := [
	"None", "Simple", "Deep", "Loose", "Pointed", "Rounded", "Traveler", "Ranger",
	"Wizard", "Assassin", "Knight", "Royal", "Fur", "Winter", "Rain", "Forest",
	"Desert", "Shadow", "Dragon", "Runic", "HighCraft"
]
const CAPS := [
	"None", "Baseball", "Flat Cap", "Beanie", "Bucket", "Cowboy", "Top Hat",
	"Fedora", "Beret", "Sailor", "Chef", "Crown", "Tiara", "Viking", "Knight",
	"Wizard", "Witch", "Pirate", "Straw", "Miner", "HighCraft"
]
const BEARDS := ["None", "Stubble", "Goatee", "Full Beard", "Long Beard", "Moustache"]
const GLASSES := ["None", "Round", "Square", "Aviator", "Sport", "Monocle", "Sunglasses"]
const MOUTHS := [
	"None", "Neutral", "Short Neutral", "Wide Neutral", "Soft Smile", "Wide Smile",
	"Small Smile", "Left Smirk", "Right Smirk", "Confident", "Friendly", "Shy",
	"Serious", "Frown", "Small Frown", "Uneven", "Open Corner", "Cute", "Old Smile",
	"Old Serious", "Hero", "Pixel Grin"
]

static func defaults() -> Dictionary:
	return {
		"name": "Afro Steve", "gender": 0, "age": 2, "build": 1, "chest_size": 1,
		"hair_style": 0, "outfit_style": 0, "cape_style": 0, "hood_style": 0,
		"cap_style": 0, "beard_style": 0, "glasses_style": 0, "mouth_style": 1,
		"skin_color": Color(0.55, 0.35, 0.2), "hair_color": Color(0.08, 0.04, 0.0),
		"eye_color": Color(0.2, 0.5, 0.9), "shirt_color": Color(0.1, 0.55, 0.9),
		"pants_color": Color(0.15, 0.15, 0.25), "cape_color": Color(0.55, 0.05, 0.1),
		"hood_color": Color(0.12, 0.14, 0.18), "cap_color": Color(0.15, 0.2, 0.55),
		"pixel_color": Color(1.0, 0.85, 0.2), "pixels": []
	}

static func body_dimensions(data: Dictionary) -> Dictionary:
	var gender := int(data.get("gender", 0))
	var age := int(data.get("age", 2))
	var build := int(data.get("build", 1))
	var height = [0.74, 0.93, 1.0, 0.95][clampi(age, 0, 3)]
	var width = [0.76, 1.0, 1.25][clampi(build, 0, 2)]
	var torso := Vector3(0.55 * width, 0.85 * height, 0.3 + 0.025 * build)
	if gender == 1:
		torso.x *= 0.9
	# Arm pivots stay close to the block torso; neither body gets comic-book shoulders.
	var shoulder := torso.x * 0.5 + (0.095 if gender == 1 else 0.11)
	var hip := torso.x * (0.72 if gender == 0 else 0.86)
	var head_scale = [1.13, 1.03, 1.0, 1.02][clampi(age, 0, 3)]
	var limb_scale = [0.82, 0.92, 1.0, 0.96][clampi(age, 0, 3)]
	return {"height": height, "torso": torso, "shoulder": shoulder, "hip": hip,
		"head_scale": head_scale, "limb_scale": limb_scale}
