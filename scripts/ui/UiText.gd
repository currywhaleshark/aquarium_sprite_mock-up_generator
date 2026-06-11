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
	"caudal": "꼬리지느러미",
	"adipose_fin": "기름지느러미",
	"finlet": "토막지느러미",
	"cephalic": "두흉엽"
}

const RAY_FIN_SLOTS := {
	"cephalic": "두흉엽",
	"pelvic": "골반엽"
}

const OPTION_LABELS := {
	"alternating": "엇갈림 (비동기)",
	"synchronous": "일치 (동기)",
	"rolled": "말림 (섭식)",
	"unfolded": "펼침 (유영)",
	"rajiform": "물결파 (Stingray)",
	"mobuliform": "날개짓 (Manta)",
	"punting": "바닥 보행 (Skate)",
	"manta": "쥐가오리형 (Manta)",
	"eagle": "매가오리형 (Eagle)",
	"cownose": "소코가오리형 (Cownose)",
	"diamond": "마름모형",
	"round": "원반형",
	"electric": "전기가오리형",
	"whip": "채찍꼬리",
	"manta_thread": "만타 실꼬리",
	"stout_skate": "스케이트 굵은꼬리",
	"short_round": "짧은 둥근꼬리",
	"single": "기본형",
	"nub": "작은 돌기형",
	"soft": "연조형",
	"spiny": "가시형",
	"mixed": "혼합형",
	"threaded": "실지느러미형",
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
	"wen": "육혹 (Wen)",
	"nuchal_hump": "이마 혹",
	"cheek_pad": "볼 패드",
	"forehead_bump": "앞머리 혹",
	"line": "선",
	"crescent": "초승달형",
	"plate": "아가미판",
	"operculum": "아가미덮개",
	"cory": "코리형 수염",
	"loach": "미꾸라지형 수염",
	"koi": "잉어형 수염",
	"bead": "구슬눈",
	"large": "큰 눈",
	"telescope": "망원경눈",
	"celestial": "하늘눈",
	"tiny_puffer": "작은 복어눈",
	"dot": "점",
	"lip": "입술",
	"beak": "부리",
	"sucker": "흡착입",
	"downturned": "아래로 꺾인 입",
	"terminal": "정면 입",
	"superior": "위쪽 입",
	"inferior": "아래쪽 입",
	"subterminal": "아래 앞쪽 입",
	"protrusible": "돌출 입",
	"forked_shallow": "얕은 갈래형",
	"forked_deep": "깊은 갈래형",
	"fan": "부채형",
	"double_fan": "쌍부채형",
	"halfmoon": "하프문",
	"veil": "베일형",
	"crowntail": "크라운테일",
	"spade": "스페이드형",
	"lyre": "라이어형",
	"top_sword": "윗소드형",
	"bottom_sword": "아랫소드형",
	"double_sword": "더블소드형",
	"butterfly": "나비형",
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
	"custom": "사용자 정의",
	"stripes": "세로 줄무늬",
	"horizontal_stripes": "가로 줄무늬",
	"spots": "점무늬",
	"zebra": "얼룩말무늬",
	"marbled": "대리석무늬",
	"reticulated": "망상무늬",
	"whale_grid": "고래상어 격자무늬",
	"manual": "수동",
	"countershade": "배색 강조",
	"complementary": "보색",
	"analogous": "유사색",
	"muted": "차분한 색",
	"cycloid": "원형비늘 (Cycloid)",
	"ctenoid": "빗비늘 (Ctenoid)",
	"ganoid": "굳비늘 (Ganoid)",
	"placoid": "방패비늘 (Placoid)",
	"pearlscale": "진주비늘 (Pearlscale)"
}

const PARAMETER_LABELS := {
	"body_length": "몸통 길이",
	"body_height": "몸통 높이",
	"body_width": "몸통 폭",
	"head_offset": "머리 위치",
	"head_size": "머리 크기",
	"head_shape": "머리 형태",
	"snout_length": "주둥이 길이",
	"snout_base": "주둥이 폭(돌출 범위)",
	"snout_thickness": "주둥이 굵기",
	"snout_taper": "주둥이 뾰족함",
	"snout_curve": "주둥이 휨(아래 ↔ 위)",
	"head_top_curve": "등선 융기(오목 ↔ 볼록)",
	"head_top_peak": "융기 위치(앞 ↔ 뒤)",
	"head_belly_curve": "배선(납작 ↔ 둥금)",
	"head_bump_height": "혹 크기",
	"head_bump_pos": "혹 위치(앞 ↔ 뒤)",
	"head_bump_width": "혹 폭",
	"head_bump_angle": "혹 각도(위 ↔ 앞)",
	"head_bump_round": "혹 윤곽(부드럽 ↔ 뚜렷)",
	"head_top_flatness": "머리 위쪽 평평함",
	"head_bottom_flatness": "머리 아래쪽 평평함",
	"head_left_flatness": "머리 왼쪽 평평함",
	"head_right_flatness": "머리 오른쪽 평평함",
	"forehead_slope": "이마 경사",
	"snout_appendage": "머리 부착물",
	"snout_appendage_length": "부착물 길이",
	"head_ornament": "머리 장식",
	"gill_mark": "아가미 표시",
	"operculum_size": "아가미덮개 길이",
	"operculum_height": "아가미덮개 높이",
	"operculum_open": "아가미덮개 열림",
	"operculum_ridge": "아가미덮개 경계",
	"operculum_position_x": "아가미덮개 X 위치",
	"operculum_position_y": "아가미덮개 Y 위치",
	"barbel_style": "수염 형태",
	"eye_style": "눈 형태",
	"mouth_detail": "입 디테일",
	"jaw_offset": "턱 위치",
	"mouth_type": "입 방향",
	"mouth_size": "입 크기",
	"mouth_open": "입 벌림",
	"lower_jaw_length": "아래턱 길이",
	"lower_jaw_angle": "아래턱 각도",
	"lower_jaw_thickness": "아래턱 두께",
	"lower_jaw_tip": "아래턱 끝(뾰족 ↔ 뭉툭)",
	"jaw_hinge_x": "턱 길이(경첩)",
	"jaw_hinge_y": "경첩 높이",
	"jaw_protrusion": "상악 돌출",
	"lower_upper_ratio": "아래/위턱 비율",
	"head_flattening": "머리 납작함",
	"eye_size": "눈 크기",
	"eye_position_x": "눈 X 위치",
	"eye_position_y": "눈 Y 위치",
	"eye_bulge": "눈 돌출",
	"eye_pupil_scale": "동공 크기",
	"eye_iris_color": "홍채 색",
	"tail_length": "꼬리 길이",
	"tail_height": "꼬리 높이",
	"tail_fin_size": "꼬리지느러미 크기",
	"caudal_height_scale": "꼬리지느러미 높이",
	"fin_softness": "지느러미 부드러움",
	"fin_rigidity": "지느러미 빳빳함",
	"fin_ray_style": "기조 스타일",
	"fin_ray_root_bias": "기조 중심",
	"fin_ray_spread": "기조 펼침",
	"fin_spine_count": "가시 기조 수",
	"fin_spine_strength": "가시 기조 선명도",
	"fin_ray_branching": "기조 갈라짐",
	"fin_ray_segmentation": "기조 마디",
	"fin_ray_irregularity": "기조 불규칙성",
	"adipose_fin_enabled": "기름지느러미",
	"adipose_fin_size": "기름지느러미 크기",
	"adipose_fin_position": "기름지느러미 위치",
	"adipose_fin_height": "기름지느러미 높이",
	"adipose_fin_roundness": "기름지느러미 둥글기",
	"adipose_fin_opacity": "기름지느러미 투명도",
	"adipose_fin_rayed": "기름지느러미 기조 예외",
	"finlet_enabled": "토막지느러미",
	"finlet_dorsal_count": "등쪽 토막 개수",
	"finlet_ventral_count": "배쪽 토막 개수",
	"finlet_size": "토막 크기",
	"finlet_taper": "토막 작아짐",
	"finlet_spacing": "토막 간격",
	"finlet_pitch": "토막 기울기",
	"finlet_color_blend": "토막 색 섞임",
	"caudal_softness": "꼬리지느러미 부드러움",
	"caudal_rigidity": "꼬리지느러미 빳빳함",
	"dorsal_1_softness": "등지느러미 1 부드러움",
	"dorsal_1_rigidity": "등지느러미 1 빳빳함",
	"dorsal_2_softness": "등지느러미 2 부드러움",
	"dorsal_2_rigidity": "등지느러미 2 빳빳함",
	"anal_softness": "뒷지느러미 부드러움",
	"anal_rigidity": "뒷지느러미 빳빳함",
	"pelvic_softness": "배지느러미 부드러움",
	"pelvic_rigidity": "배지느러미 빳빳함",
	"pectoral_softness": "가슴지느러미 부드러움",
	"pectoral_rigidity": "가슴지느러미 빳빳함",
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
	"pectoral_fin_yaw": "가슴지느러미 벌림 각도",
	"pectoral_fin_pitch": "가슴지느러미 비틀림 각도",
	"pectoral_fin_roll": "가슴지느러미 수평 각도",
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
	"pectoral_flap_sync": "가슴지느러미 유영 모드",
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
	"scale_type": "비늘 종류",
	"scale_strength": "비늘 선명도",
	"scale_size": "비늘 크기",
	"pearlscale_strength": "진주비늘 볼록함",
	"metallic_scale_strength": "금속 광택 강도",
	"lateral_line_strength": "측선 선명도",
	"emissive_marking_strength": "발광 무늬 강도",
	"pattern_type": "무늬 종류",
	"pattern_color": "무늬 색",
	"pattern_scale_x": "무늬 가로 크기",
	"pattern_scale_y": "무늬 세로 크기",
	"pattern_intensity": "무늬 진하기",
	"pattern_invert": "무늬 반전",
	"pattern_seed": "무늬 씨앗",
	"pattern_size_lock": "몸 크기 기준 무늬 밀도",
	"marking_layers": "부위별 무늬 레이어",
	"marking_layer_type": "레이어 종류",
	"marking_layer_region": "부위",
	"marking_layer_blend_mode": "합성 방식",
	"marking_layer_intensity": "강도",
	"marking_layer_color": "레이어 색",
	"marking_layer_x_start": "시작 위치",
	"marking_layer_x_end": "끝 위치",
	"marking_layer_thickness": "두께",
	"palette_scheme": "색 조합 방식",
	"fin_color": "지느러미 색",
	"outline_color": "외곽선 색",
	"outline_width": "외곽선 두께",
	"highlight_strength": "하이라이트 강도",
	"shadow_strength": "그림자 강도",
	"shell_enabled": "몸통 쉘 표시",
	"shell_expand": "쉘 확장",
	"shell_color_mix": "쉘 색상 혼합",
	"shell_opacity": "쉘 투명도",
	"shell_roundness": "디스크 둥글기",
	"wave_ripples": "물결 파동수",
	"cephalic_horns": "두흉엽",
	"ray_locomotion_mode": "가오리 유영 방식",
	"ray_head_shape": "가오리 머리 형태",
	"ray_disc_shape": "가오리 디스크 형태",
	"ray_tail_style": "가오리 꼬리 형태",
	"ray_tail_spine_enabled": "꼬리 가시",
	"ray_dorsal_tail_fins": "꼬리 등지느러미",
	"eye_spacing": "눈 간격",
	"disc_width": "가오리 몸 폭",
	"disc_length": "가오리 몸 길이",
	"disc_thickness": "가오리 몸 두께",
	"wing_width": "날개 폭",
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
	"Scale Settings": "비늘 설정",
	"Visual Settings": "시각 설정",
	"Global Settings": "전체 설정",
	"Export": "출력",
	"Other": "기타"
}

const REFERENCE_LABELS := {
	"scale": "크기",
	"rotation": "회전(°)",
	"offset_x": "X 위치",
	"offset_y": "Y 위치",
	"opacity": "투명도"
}

const RING_PARAMETER_LABELS := {
	"x": "몸 길이 위치",
	"y_offset": "상하 중심 이동",
	"upper_height": "위쪽 높이",
	"lower_height": "아래쪽 높이",
	"width": "전체 폭",
	"top_width": "위쪽 폭",
	"bottom_width": "아래쪽 폭",
	"top_flatness": "위쪽 평평함",
	"bottom_flatness": "아래쪽 평평함",
	"left_flatness": "왼쪽 평평함",
	"right_flatness": "오른쪽 평평함",
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

static func ray_fin_slot(slot_id: String) -> String:
	return String(RAY_FIN_SLOTS.get(slot_id, fin_slot(slot_id)))

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

static func fin_parameter(key: String) -> String:
	if key.contains("_bezier_"):
		if key.ends_with("p1_x"):
			return "조절점 1 X"
		elif key.ends_with("p1_y"):
			return "조절점 1 Y"
		elif key.ends_with("p2_x"):
			return "조절점 2 X"
		elif key.ends_with("p2_y"):
			return "조절점 2 Y"
	if key.ends_with("_softness"):
		return "부드러움"
	if key.ends_with("_rigidity"):
		return "빳빳함"
	if key.ends_with("_length"):
		return "길이"
	if key.ends_with("_height"):
		return "높이"
	if key == "caudal_height_scale":
		return "높이"
	if key.ends_with("_size"):
		return "크기"
	if key.ends_with("_offset_x"):
		return "X 오프셋"
	if key == "pectoral_offset_y":
		return "Y 오프셋"
	if key == "pectoral_fin_yaw":
		return "벌림 각도"
	if key == "pectoral_fin_pitch":
		return "비틀림 각도"
	if key == "pectoral_fin_roll":
		return "수평 각도"
		
	var base_label := parameter(key)
	for slot_name in ["가슴지느러미 ", "배지느러미 ", "등지느러미 1 ", "등지느러미 2 ", "등지느러미 ", "뒷지느러미 ", "꼬리지느러미 "]:
		if base_label.begins_with(slot_name):
			return base_label.substr(slot_name.length())
	return base_label

static func section(section_name: String) -> String:
	return String(SECTION_LABELS.get(section_name, section_name))

static func reference_label(key: String) -> String:
	return String(REFERENCE_LABELS.get(key, parameter(key)))

static func ring_parameter(key: String) -> String:
	return String(RING_PARAMETER_LABELS.get(key, parameter(key)))

static func changed_only_filter() -> String:
	return "변경된 항목만"

static func slider_search_placeholder() -> String:
	return "슬라이더 검색"

static func _humanize(value: String) -> String:
	return value.replace("_", " ")
