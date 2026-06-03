# 머리 편집 자유도 개선 계획 (Head Sculpt Rework)

작성: 2026-06-03

## 배경 / 목표

어류 스프라이트 생성기의 머리 편집이 직관적이지 않고 원하는 형태로 다듬기 어렵다.
**프리셋 카테고리를 늘리는 대신 편집 자유도 자체를 높이는 것**이 목표.

대응하고자 하는 대표 형상:
- 나비고기(butterflyfish) — 정상 머리에서 가늘게 튀어나온 관 모양 주둥이
- 쥐치복류(triggerfish/filefish) — 부리 같은 주둥이
- 나폴레옹피쉬(humphead wrasse) — 특징적인 이마 혹
- 특정 금붕어종 — 볼록한 볼혹(cheek bump)
- 아로와나(arowana) — 위가 납작한 직선 등선 머리

## 진단한 근본 원인

1. **주둥이 = 머리 앞쪽 절반 전체 신장.** `snout_length` 스칼라 하나가 앞쪽 절반을
   `stretch_t²` 가중치로 끌어당기고, 입 위치는 별도 계산
   (`FishRig._mouth_position_for_type`). → "가는 관 주둥이"와 "머리 전체 신장"을 구분 불가.
2. **혹/장식이 고정 크기 + 머리 스케일 종속.** `FishRig._add_head_ornament`가
   하드코딩 크기 타원체를 머리 노드(`head.scale = head_scale`)의 자식으로 부착 →
   크기/위치/형태 컨트롤 없음, 머리 크기 조절 시 함께 확대됨.
3. **이산 `head_shape` enum이 두 효과를 혼재.** 스케일 배수(`_head_scale_for_shape`)와
   메시 변형(`deformed_head_mesh`)을 동시에 하드코딩, `forehead_slope`는 일부 형태에만 노출.
4. **변형 수식이 두 경로에 중복.** 전방 메시 빌더와 역방향 셸 정합기가 같은 수식을
   각각 구현 → 신규 파라미터 추가 시 양쪽 동기화 부담. (Phase 0에서 해소)

## 핵심 결정 (사용자 확정)

- 혹/볼혹: **표면 국소 변형 + 부착 메시 둘 다** 지원.
- 이산 `head_shape` / `head_ornament` enum: **삭제하지 않고 "기본값 프리셋"으로만 유지** —
  선택 시 신규 연속 슬라이더에 값을 주입하는 시작점 역할.
- 진행: **단계별 PR로 점진 진행.**

## 단계 (Phases)

- **Phase 0 — 변형 수식 단일화 (완료)**
  `scripts/creature/HeadProfile.gd` 신설, 머리 실루엣 상수/수식을 한 곳에 모음.
  `PrimitiveFactory.deformed_head_mesh`(전방)와 `FishRig._get_head_contour_radius`(역방향)가
  이 모듈만 참조하도록 변경. 동작 무변화, 전체 35개 테스트 통과.

- **Phase 1 — 주둥이를 독립 세그먼트로 분리**
  신규: `snout_base`(주둥이 솟는 지점 폭), `snout_thickness`/`snout_taper`(관 굵기·끝 가늘기),
  `snout_tip_round`(끝 둥글기). 변형을 `u`의 좁은 전방 윈도에만 집중(스무스 블렌딩).
  입은 항상 주둥이 끝에 앵커링(`_mouth_position_for_type`이 주둥이 끝 참조).

- **Phase 2 — 등선/배선 프로파일을 연속 컨트롤로**
  `head_top_profile`(오목↔직선↔볼록), `head_top_peak_pos`(최고점 위치),
  `head_bottom_profile`. 기존 hump/steep_forehead/flattened/forehead_slope를 흡수.
  flatten 메시(0.65) vs 컨트롤(0.825) 불일치도 여기서 정리.

- **Phase 3 — 혹/볼혹 파라메트릭 + 머리 스케일에서 독립**
  국소 가우시안 표면 범프(솔기 없는 연속 표면) 및 절대크기 부착 메시.
  컨트롤: position(x,y,z), size(x,y,z), softness/blend, 좌우 대칭. 머리 메시 테셀레이션 점검.

- **Phase 4 — UI 재구성 (`HeadEditorPanel`)**
  신규 numeric 키 추가, `UiText` 한글 라벨, 접이식 섹션화
  (머리 본체 / 주둥이 / 등선·배선 / 혹·볼혹 / 입·눈). 조건부 노출 로직 갱신.

- **Phase 5 — 하위호환 / 마이그레이션**
  기존 `head_shape`/`head_ornament` enum → 신규 연속 파라미터 기본값 매핑
  (`ensure_head_parameters` 신설, `BodyProfile.ensure_visual_parameters` 인근).
  프리셋 6종 재검수.

- **Phase 6 — 테스트 / 검증**
  Head*Test, ShellRigTest, ParameterPanel*Test 갱신. 메시 정점 vs 셸 반경 정합 회귀 테스트.
  대표 5종 실루엣을 신규 슬라이더만으로 재현 가능한지 수동 검증.

## 참고

- 테스트: `tools/run_godot_cli_tests.ps1` (Godot 4.6.2 headless, 35 scenes).
- `HeadProfile`는 전역 `class_name`이 아니라 preload 상수로 참조한다
  (headless 실행이 신규 전역 클래스를 인식하지 못함).
