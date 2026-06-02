class_name UiText
extends RefCounted

const PRESET_NAMES := {
	"basic_fish": "기본 물고기",
	"default_fish": "기본 물고기",
	"round_chubby_fish": "둥글고 통통한 물고기",
	"slender_fish": "가느다란 물고기",
	"tall_flat_fish": "높고 납작한 물고기",
	"bottom_dweller_fish": "바닥 생활형 물고기",
	"long_fish": "긴 물고기",
	"high_body_fish": "높은 체형 물고기",
	"goldfish": "금붕어",
	"basic_ray": "기본 가오리",
	"manta_ray": "만타가오리"
}

const CREATURE_TYPES := {
	"fish": "물고기",
	"ray": "가오리"
}

const CAMERA_PRESETS := {
	"aquarium_side_quarter": "수조 측면 3/4",
	"ray_top_quarter": "가오리 상단 3/4",
	"shark_side_quarter": "상어 측면 3/4"
}

const BODY_RINGS := {
	"snout": "주둥이",
	"head": "머리",
	"front_body": "앞몸통",
	"mid_body": "중앙 몸통",
	"rear_body": "뒷몸통",
	"tail_stem": "꼬리자루"
}

const FIN_SLOTS := {
	"dorsal_1": "등지느러미 1",
	"dorsal_2": "등지느러미 2",
	"pectoral": "가슴지느러미",
	"pelvic": "배지느러미",
	"anal": "뒷지느러미",
	"caudal": "꼬리지느러미"
}

const OPTION_LABELS := {
	"single": "기본형",
	"spiny": "가시형",
	"split": "갈라진 형",
	"trailing": "늘어진 형",
	"trigger": "쐐기형",
	"oval": "타원형",
	"triangle": "삼각형",
	"long": "긴 형",
	"rounded": "둥근 형",
	"tapered": "점점 좁아짐",
	"pointed": "뾰족함",
	"blunt": "뭉툭함",
	"broad": "넓은 형",
	"flattened": "납작함",
	"hump": "혹 있는 형",
	"steep_forehead": "가파른 이마",
	"cephalofoil": "망치형 (Cephalofoil)",
	"none": "없음",
	"swordfish_bill": "황새치 부리",
	"sawfish_saw": "톱가오리 톱",
	"barbels": "메기 수염 (Barbels)",
	"terminal": "정면 입",
	"superior": "위쪽 입",
	"inferior": "아래쪽 입",
	"subterminal": "아래 앞쪽 입",
	"protrusible": "돌출 입",
	"forked_shallow": "얕은 갈래형",
	"forked_deep": "깊은 갈래형",
	"truncate": "절단형",
	"lunate": "초승달형",
	"shark_heterocercal": "상어형 비대칭",
	"thresher": "환도상어형",
	"eel": "장어형",
	"general": "일반형",
	"mackerel": "고등어형",
	"tuna": "참치형",
	"puffer": "복어형",
	"boxfish": "박스피시형",
	"bezier": "베지에 제어형",
	"stripes": "세로 줄무늬",
	"horizontal_stripes": "가로 줄무늬",
	"spots": "점무늬",
	"zebra": "얼룩말무늬",
	"marbled": "대리석무늬",
	"reticulated": "망상무늬"
}

const PARAMETER_LABELS := {
	"body_length": "몸통 길이",
	"body_height": "몸통 높이",
	"body_width": "몸통 폭",
	"head_offset": "머리 위치",
	"head_size": "머리 크기",
	"head_shape": "머리 형태",
	"snout_length": "주둥이 길이",
	"forehead_slope": "이마 경사",
	"snout_appendage": "머리 부착물",
	"snout_appendage_length": "부착물 길이",
	"jaw_offset": "턱 위치",
	"mouth_type": "입 방향",
	"mouth_size": "입 크기",
	"head_flattening": "머리 납작함",
	"eye_size": "눈 크기",
	"eye_position_x": "눈 X 위치",
	"eye_position_y": "눈 Y 위치",
	"eye_bulge": "눈 돌출",
	"tail_length": "꼬리 길이",
	"tail_height": "꼬리 높이",
	"tail_fin_size": "꼬리지느러미 크기",
	"caudal_height_scale": "꼬리지느러미 높이",
	"dorsal_1_length": "등지느러미 1 길이",
	"dorsal_1_height": "등지느러미 1 높이",
	"dorsal_2_length": "등지느러미 2 길이",
	"dorsal_2_height": "등지느러미 2 높이",
	"pectoral_fin_size": "가슴지느러미 크기",
	"pelvic_length": "배지느러미 길이",
	"pelvic_height": "배지느러미 높이",
	"anal_length": "뒷지느러미 길이",
	"anal_height": "뒷지느러미 높이",
	"dorsal_1_attach_t": "등지느러미 1 부착 위치",
	"dorsal_2_attach_t": "등지느러미 2 부착 위치",
	"pectoral_attach_t": "가슴지느러미 부착 위치",
	"pelvic_attach_t": "배지느러미 부착 위치",
	"anal_attach_t": "뒷지느러미 부착 위치",
	"dorsal_fin_offset_x": "등지느러미 X 오프셋",
	"pectoral_fin_offset_x": "가슴지느러미 X 오프셋",
	"anal_fin_offset_x": "뒷지느러미 X 오프셋",
	"dorsal_2_enabled": "등지느러미 2 사용",
	"pelvic_enabled": "배지느러미 사용",
	"swim_speed": "헤엄 속도",
	"swim_mode": "헤엄 방식",
	"global_sway_amount": "전체 흔들림",
	"phase_delay": "위상 지연",
	"tail_sway_multiplier": "꼬리 흔들림 배율",
	"tail_fin_extra_swing": "꼬리지느러미 추가 회전",
	"body_wave_amount": "몸통 파동 강도",
	"body_wave_start": "몸통 파동 시작점",
	"body_wave_falloff": "몸통 파동 분포",
	"fin_flap_amount": "지느러미 퍼덕임",
	"fin_yaw_follow_strength": "지느러미 몸통 추적",
	"median_fin_wave_amount": "정중선 지느러미 물결",
	"median_fin_flap_amount": "등/뒷지느러미 추진",
	"median_fin_flap_phase": "등/뒷지느러미 위상",
	"idle_bob_amount": "유휴 상하 움직임",
	"base_color": "기본 색",
	"secondary_color": "보조 색",
	"belly_color": "배 색",
	"belly_height": "배 색 영역 높이",
	"belly_slope": "배 색 경계 부드러움",
	"iridescence_strength": "무지개빛 광택",
	"iridescence_color": "무지개빛 색",
	"iridescence_frequency": "무지개빛 빈도",
	"wetness": "젖은 광택",
	"pattern_type": "무늬 종류",
	"pattern_color": "무늬 색",
	"pattern_scale_x": "무늬 가로 크기",
	"pattern_scale_y": "무늬 세로 크기",
	"pattern_intensity": "무늬 진하기",
	"fin_color": "지느러미 색",
	"outline_color": "외곽선 색",
	"outline_width": "외곽선 두께",
	"highlight_strength": "하이라이트 강도",
	"shadow_strength": "그림자 강도",
	"shell_enabled": "몸통 쉘 표시",
	"shell_expand": "쉘 확장",
	"shell_color_mix": "쉘 색상 혼합",
	"shell_opacity": "쉘 투명도",
	"orthographic_size": "카메라 줌",
	"camera_yaw": "카메라 좌우 회전",
	"camera_pitch": "카메라 상하 회전",
	"camera_roll": "카메라 기울기",
	"frame_count": "프레임 수",
	"frame_ticks": "프레임 간격",
	"output_resolution": "출력 해상도",
	"target_display_w": "표시 폭",
	"target_display_h": "표시 높이"
}

const SECTION_LABELS := {
	"Head": "머리",
	"Fins": "지느러미",
	"Motion Settings": "움직임 설정",
	"Color Settings": "색상 설정",
	"Pattern Settings": "무늬 설정",
	"Visual Settings": "시각 설정",
	"Global Settings": "전체 설정",
	"Export": "출력",
	"Other": "기타"
}

const REFERENCE_LABELS := {
	"scale": "크기",
	"offset_x": "X 위치",
	"offset_y": "Y 위치",
	"opacity": "투명도"
}

const RING_PARAMETER_LABELS := {
	"x": "몸 길이 위치",
	"y_offset": "상하 중심 이동",
	"upper_height": "위쪽 높이",
	"lower_height": "아래쪽 높이",
	"width": "두께",
	"roundness": "둥글기",
	"sway_weight": "흔들림 반응"
}

static func preset_name(value: String) -> String:
	return String(PRESET_NAMES.get(value, _humanize(value)))

static func creature_type(value: String) -> String:
	return String(CREATURE_TYPES.get(value, _humanize(value)))

static func camera_preset(value: String) -> String:
	return String(CAMERA_PRESETS.get(value, _humanize(value)))

static func body_ring(ring_id: String, fallback: String = "") -> String:
	if BODY_RINGS.has(ring_id):
		return String(BODY_RINGS[ring_id])
	return fallback if fallback != "" else _humanize(ring_id)

static func fin_slot(slot_id: String) -> String:
	return String(FIN_SLOTS.get(slot_id, _humanize(slot_id)))

static func option(value: String) -> String:
	return String(OPTION_LABELS.get(value, _humanize(value)))

static func parameter(key: String) -> String:
	if key.contains("_bezier_"):
		var suffix := ""
		if key.ends_with("p1_x"):
			suffix = " 조절점 1 X"
		elif key.ends_with("p1_y"):
			suffix = " 조절점 1 Y"
		elif key.ends_with("p2_x"):
			suffix = " 조절점 2 X"
		elif key.ends_with("p2_y"):
			suffix = " 조절점 2 Y"
		var parts := key.split("_bezier_")
		var slot_key := parts[0]
		var slot_name := fin_slot(slot_key)
		return slot_name + suffix
	return String(PARAMETER_LABELS.get(key, _humanize(key)))

static func section(section_name: String) -> String:
	return String(SECTION_LABELS.get(section_name, section_name))

static func reference_label(key: String) -> String:
	return String(REFERENCE_LABELS.get(key, parameter(key)))

static func ring_parameter(key: String) -> String:
	return String(RING_PARAMETER_LABELS.get(key, parameter(key)))

static func _humanize(value: String) -> String:
	return value.replace("_", " ")
