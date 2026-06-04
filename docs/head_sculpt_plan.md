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

- **Phase 2 — 등선/배선 프로파일을 연속 컨트롤로 (완료)**
  `head_top_curve`(오목↔볼록), `head_top_peak`(최고점 위치), `head_belly_curve`(납작↔둥금)
  추가. 중립 기본값(가산식)이라 기존 프리셋 불변, 이산 hump/steep/flattened는 시작점으로 유지.
  몸통 셸 contour도 이제 연속 프로파일+혹을 반영(반경 증가 + center_y 시프트로 비대칭 성장,
  `_apply_head_shell_metrics`). 추후: flatten 메시(0.65) vs 컨트롤(0.825) 불일치 정리.

- **Phase 3 — 혹/볼혹 파라메트릭 + 머리 스케일에서 독립**
  국소 가우시안 표면 범프(솔기 없는 연속 표면) 및 절대크기 부착 메시.
  컨트롤: position(x,y,z), size(x,y,z), softness/blend, 좌우 대칭. 머리 메시 테셀레이션 점검.

- **Phase 3 — 혹 파라메트릭 (완료)**
  머리 윗면 국소 돔 혹: `head_bump_height/pos/width/angle/round`. 경계가 분명한 돔이라
  앞으로(각도) 돌출 가능. 표면 변형 방식만 구현(부착 메시·좌우 측면 볼혹은 추후).

- **Phase 4 — UI 재구성 (`HeadEditorPanel`) (완료)**
  접이식 섹션화 완료(머리 본체 / 주둥이 / 등선·배선 / 혹 / 입 / 눈, 가오리는 단일 머리 그룹).
  헤더 클릭 토글 + 펼침 상태 유지, 미사용 키 누락 방지용 기타 그룹. 조건부 노출 로직 유지.

- **Phase 5 — 하위호환 / 마이그레이션**
  기존 `head_shape`/`head_ornament` enum → 신규 연속 파라미터 기본값 매핑
  (`ensure_head_parameters` 신설, `BodyProfile.ensure_visual_parameters` 인근).
  프리셋 6종 재검수.

- **Phase 6 — 테스트 / 검증**
  Head*Test, ShellRigTest, ParameterPanel*Test 갱신. 메시 정점 vs 셸 반경 정합 회귀 테스트.
  대표 5종 실루엣을 신규 슬라이더만으로 재현 가능한지 수동 검증.

## 진행 현황 (2026-06-04 기준)

- 브랜치: `head-sculpt/phase0-unify-profile` (main에서 분기, 아직 PR 없음).
- 완료: Phase 0(수식 단일화) · 1(주둥이 분리 + 턱 전단 + 주둥이 휨) · 2(등선/배선 연속
  프로파일) · 3(전방 돌출 돔 혹: 크기/위치/폭/각도/윤곽) · 4(접이식 섹션 UI) ·
  5의 일부(몸통 셸이 프로파일/혹 반영).
- 전체 35개 테스트 통과.

## 진행 추가분 (2026-06-04 저녁, 아로와나 재현 중)

Phase 6 검증을 아로와나 프리셋으로 진행하던 중 발견·처리한 내용.

- **완료: 참조 이미지 회전 슬라이더.** 오버레이에 `rotation`(−180°~180°) 추가.
  `ReferenceImagePanel.NUMERIC_SETTINGS`/기본 settings, `UiText.REFERENCE_LABELS`("회전(°)"),
  `Main._default_reference_image_settings` + `_update_reference_overlay_transform`(중심
  pivot 기준 `rotation_degrees`). 기본값 0이라 기존 외형/테스트 불변.
- **완료: 머리 단차(swim 애니메이션 한정) 수정.** `FishRig._deform_shell`에서 snout·head
  링(0,1)을 머리 노드에 정렬하며 덮어쓸 때 `shell_center_y_offsets`가 이중 적용되던 버그.
  `head_center`에 이미 보간 offset이 포함되는데 메시 빌더와 `_animated_ring_center`가 또
  더해, 머리 영역만 ~offset(≈0.097)만큼 솟아 front_body와 단차 발생(rest에선 정상).
  수정: 링 덮어쓸 때 각 링의 raw y 보존, yaw 회전·x/z 이동만 머리 운동에 따름.
  헤드리스 프로브로 head.y 0.097, 셸 head top 0.322 확인(이전 0.19/0.42). 35개 테스트 통과.

### 아직 남은 머리 이슈 (사용자 테스트로 확인, 미해결)

- **머리가 갈라져 속(내부 backface)이 보이는 부분.** 머리 구체 메시와 몸통 셸이 만나는
  솔기에서 둘이 완전히 겹치지 않아 틈이 보임. (앞에서 봤을 때 머리-셸 사이 빈 공간은
  파라미터 조절로 들어갔다고 함 → 남은 건 옆/특정 각도의 갈라짐.) 두 표면 겹침 구간
  정합 또는 솔기 캡 필요.
- **눈이 앞으로 더 안 나감(막힘).** `eye_position_x` 슬라이더 범위는 −1.5까지 열려 있으나,
  `FishRig._eye_layout`이 눈을 머리 타원체에 투영하며 `max_planar = 0.9`로 클램프 → 머리
  앞 가장자리에서 더 못 나감. 주둥이가 길어진(아로와나) 경우 눈을 주둥이 쪽으로 더 보내려면
  이 클램프/투영 기준(머리 스케일 대비)을 완화하거나 주둥이 길이 반영 필요.

### 내일 할 일 (남은 작업)

0. **위 '남은 머리 이슈' 2건 우선 처리**(머리 솔기 갈라짐 · 눈 전방 한계).
1. **Phase 5 본작업(선택)**: 이산 `head_shape`(hump/steep_forehead/flattened)·
   `head_ornament` enum의 baked 변형을 제거하고 연속 파라미터로 단일화 + `ensure_head_parameters`
   신설로 기존 프리셋 매핑. 주의: 현재는 baked + 연속이 가산 공존(저위험)이라 굳이 안 해도 동작.
   진행 시 ShellRigTest/HeadEditorModelTest의 형태 의존 단언과 프리셋 외형 변화 주의.
2. **Phase 6 검증**: 대표 5종(나비고기·쥐치복·나폴레옹·금붕어·아로와나)을 신규 슬라이더만으로
   재현해 보고 부족한 컨트롤 발견·보완.
3. 후보: 좌우 측면 볼혹(금붕어 볼), 혹 복수 개, 부착 메시 방식 혹, 머리 메시 테셀레이션 상향
   (윤곽 1.0 근처 큰 혹에서 각짐), flatten 메시(0.65) vs contour(0.825) 불일치 정리.

## 참고

- 테스트: `tools/run_godot_cli_tests.ps1` (Godot 4.6.2 headless, 35 scenes).
- `HeadProfile`는 전역 `class_name`이 아니라 preload 상수로 참조한다
  (headless 실행이 신규 전역 클래스를 인식하지 못함).
- 신규 머리 파라미터는 모두 중립 기본값(가산식)이라 기존 프리셋 외형 불변.
