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

### 머리 이슈 2건 처리 (2026-06-04, 완료)

- **완료: 머리 솔기 갈라짐(내부 backface 노출).** 진단(헤드리스 지오메트리 프로브로
  머리 메시 정점이 셸 타원 밖으로 나가는지 측정): 연속 등선/배선 프로파일
  (`head_top_curve`<0 아로와나 등)에서 ① 메시 `dorsal/ventral_offset`가 `y>0/<0` 정점
  **전부에 theta 무관 균일 적용** → 옆면 정점까지 끌려나감, ② 셸은 이를 반경+중심이동
  (`center_y_delta`)으로 근사하는데 머리 노드는 `head_offset` 한 점에서만 중심 샘플 →
  x에 따라 휘는 셸 중심을 강체 머리가 못 따라가 잔차 발생. 수정:
  · `PrimitiveFactory`: dorsal/ventral 오프셋을 `abs(sin(theta))`로 가중 → 윗면/바닥
    실루엣(셸 contour가 참조하는 theta=90)은 유지, 옆면은 0으로 수렴.
  · `FishRig._apply_head_shell_metrics`: 셸 반경 바닥값을 미변형 머리 contour로 **floor**
    (`target_y = maxf(target_y, r_head_y + exp_offset_y)`) → 오목 프로파일이 셸을 머리
    기본 반경 아래로 줄여 바닥이 삐지던 것 방지. **머리 자연 크기 이상으로 키우지 않는
    하한**이라 머리를 살찌우거나 머리/몸통 단차를 만들지 않음. 중립 프로파일(기본값 0)에선
    floor가 no-op이라 기존 프리셋 불변. 프로브: 아로와나 worst_radial 1.146→0.962(<1).
  · 회귀 테스트 `HeadShellSeamTest` 신설(머리 정점이 솔기 구간에서 셸 밖으로 안 나감).
  · **회귀 1건(같은 세션에서 발생·수정)**: 처음엔 `+= abs(top_extra)+abs(bottom_extra)`
    **포위 여유(pad)**로 풀었으나, `abs()`가 오목 프로파일에서도 셸을 부풀려 머리가 거대해지고
    머리/앞몸통 **단차가 심해짐**(사용자 보고). pad 제거하고 위 floor로 교체.
  · 주의(남은 미세 케이스): 극단적 **양(+)** 프로파일(혹/배 ≥0.9)에서는 솔기 림이 아닌
    **중첩 구간 내부**에서 머리가 셸보다 살짝 볼록(worst≈1.03~1.14). 거기선 머리 표면이
    보일 뿐 내부 노출은 아니라 시각적 갈라짐은 아님.
- **완료: 눈 전방 한계.** `FishRig._eye_layout`의 `max_planar` 0.9→0.98로 완화 + 입
  앵커가 쓰는 것과 동일한 `snout_forward_x_shift`/`snout_radial_scale`를 눈 앵커에도 적용
  → 주둥이가 길면 눈이 주둥이 표면을 타고 전방으로. 프로브: 주둥이 0.6에서 눈 x −0.79→
  −1.04. `EyeAttachmentTest`에 회귀 단언 추가.
- **완료: 입을 면에 납작한 "구멍"으로 표현(1차 입술 시도→블롭 피드백 후 재작업).**
  · 1차: 어두운 입 + 위/아래 입술 타원체(`LipUpper/Lower`). 사용자 피드백: x축으로 두껍게
    돌출해 "주둥이 끝에 툭 튀어나온 구체" 같음.
  · 2차(현재): `FishRig._add_mouth`를 **x축으로 얇게(면에 플러시)** 재작성. 어두운 구멍
    (`Mouth`, MeshInstance3D 유지 → 턱 추종·테스트 핸들) + 살짝 더 크고 어두운 본체색
    (`darkened(0.34)`)의 입술 림(`MouthLip`). `flat_x=mouth_size*0.16`로 얇게 → 블롭이 아니라
    스누트에 붙은 입. `mouth_open`(0~1, 기본 0.25)이 어두운 구멍의 **세로 높이**를 키워(half
    0.1→0.66) 실제로 벌어진 것처럼 보이게 함. 전부 unshaded라 색 대비로 표현. UI/UiText/
    ParameterPanel 등록. 회귀: `HeadEditorModelTest`에 입술 림 존재·납작(x<z)·구멍보다 큼 단언.
  · 3차(현재): 2차의 평면 디스크가 "주둥이 끝에 붙은 동전" 같다는 피드백(곡선을 안 따라감).
    `_add_mouth`를 **곡면을 따라 휘는 띠(band) 메시**로 재작성. `_mouth_band_mesh`가 머리 front
    실루엣(`_head_front_surface_x`)을 폭(z) 방향으로 샘플 → 가장자리에서 x가 뒤로 후퇴해
    **주둥이를 감쌈**. 어두운 개구 띠(`Mouth`) + 위/아래 입술 띠(`MouthLipUpper/Lower`). 좌표는
    mouth_position 기준 로컬이라 노드가 턱 전단 추종(테스트 핸들 유지). 프로브: 뾰족 주둥이0.5
    에서 가장자리 후퇴 0.032(월드), 둥근 주둥이 0.006 → 곡률 따라 자연 감쌈. `mouth_open`은
    개구 띠 세로 높이(half 0.06→0.6). 회귀 단언: 개구 띠가 가장자리에서 뒤로 휘는지 검사.
  · 4차(현재): "실제로 벌어지게" 요청 → **경첩(hinged jaw)**. 위/아래 입술 띠를 입 뒤쪽
    hinge(`mouth_position + x*mouth_size*0.55`) 기준으로 회전. **새 슬라이더 없이 기존
    `mouth_open` 재사용**(사용자 슬라이더 증가 우려 반영) → 위턱 −20°·아래턱 +34°(어류처럼
    아래턱이 더 내려감)까지 벌어짐. 어두운 개구 띠는 `mouth_open`으로 세로로 커져 벌어진 안쪽을
    노출. 프로브: 앞 가장자리 간격 open0→0.006, 0.5→0.050, 1.0→0.082(아래턱 중심 아래로).
    회귀: `HeadEditorModelTest`에 mouth_open 0 vs 1 턱 간격 증가 단언.
  · 5차(현재): "벌어질 때 머리 메시 안으로 파묻힘" 피드백. 원인: 경첩이 머리 내부(+x)라
    회전 시 턱 띠가 표면 뒤로 쓸려 들어감(프로브: open1.0 아래턱 0.073 파묻힘). 수정:
    `_mouth_band_mesh`가 개구 회전·입 방향 틸트를 **메시에 bake**하고, 각 정점을
    `minf(x, _head_front_surface_x(y,z))`로 **표면 앞으로 클램프**. 뒤쪽(경첩 근처)은 표면에
    붙어 미끄러지고 앞쪽 끝만 들려 벌어짐(실제 턱처럼). 프로브: 파묻힘 −0.008로 전 구간 유지,
    gape 0.014→0.177로 오히려 더 크게 벌어짐. node 회전 0(전부 bake).
  · 6차(현재): "입 크기 키우면 또 파묻힘". 원인: 클램프가 해석식 `_head_front_surface_x`(주둥이
    taper 무시)를 써서 큰 입이 taper로 들어간 실제 표면과 어긋남. 수정: `_head_mesh_front_x`
    신설 — **실제 빌드된 머리 메시 정점**에서 (y,z) 최근접 전면 정점(x<0.25) x를 읽어 클램프.
    `_add_mouth`가 `head.mesh` 정점을 넘김. 프로브(실제 메시 기준): rounded ms0.08~0.24·pointed
    ms0.24·open0.5 모두 파묻힘 음수(표면 앞). 
  · 참고: 머리가 닫힌 구체라 진짜 메시 절개는 아니고, 입술 띠가 표면을 타고 들리며 벌어지는
    방식(안쪽은 어두운 띠). 더 깊은 입속 표현 필요 시 추후.
- **완료: 눈이 턱 전단(jaw shear)을 따라감.** 위 눈 보정이 주둥이 전방 이동·굵기만 반영하고
  세로 전단/휨은 빠져, 턱을 올리/내리면 눈 이동 한계가 전단 전 실루엣에 묶이던 문제(사용자
  보고). `_eye_layout` 앵커 y에 입 앵커와 동일한 `HeadProfile.snout_y_shift(jaw_shift, u,
  snout_base, snout_curve)*scale.y` 추가(주둥이 길이와 무관, 전방 윈도 전체 적용). 프로브:
  주둥이 0.5·전방 눈에서 jaw +0.3 → eye_y 0.075→0.202, jaw −0.3 → −0.053. `EyeAttachmentTest`
  에 회귀 단언 추가.

### 비대칭(egg) 셸 링 — 위/아래 높이 커플링 해결 (완료)

증상(사용자 보고, 기존 이슈): 셸 메시 링이 `center_y` 중심 **대칭 타원**(반경 하나)이라
`upper_height`를 만지면 `radius_y`+`center_y`가 동시에 변해 아래쪽 곡률·옆 폭 위치까지
바뀜. (상/하 극단점 자체는 독립이지만 곡선 모양이 커플링.)

해결(저위험·메시 전용): 자료구조·샘플러를 안 건드리고 **메시 빌더 안에서만** 비대칭 복원.
- `FishRig`: 링별 `shell_radius_half_diff = body_height*(upper-lower)/2` 신설 배열을
  `fish_outer_shell`/`update_fish_outer_shell_bent`로 전달. `shell_profile.y`(평균 반경)와
  `shell_center_y_offsets`(시프트된 중심)는 **그대로** → 모든 샘플러·지느러미 앵커·극단점 불변.
- `PrimitiveFactory.build_fish_outer_shell_mesh`: `center_y` 안에 이미 `(u-l)/2` 시프트가
  들어있음을 이용, `true_center = center.y - hd`, `r_up = point.y + hd`, `r_lo = point.y - hd`로
  **상/하 반경 독립**(egg 단면). top=`center.y+point.y`, bottom=`center.y-point.y` 극단점은
  대칭 링과 동일하게 보존, 옆면(sin=0)은 진짜 중심선에 고정 → `upper` 만지면 윗면만 움직임.
  `hd`는 `±point.y*0.9`로 클램프(얇은 쪽 붕괴 방지).
- 프로브: `upper_height` +0.15 시 윗면 +0.087, **옆/아래 변화 0**. 회귀 테스트
  `RingHeightDecoupleTest` 신설(위/아래 각각 독립 검증).
- 영향: 기본 링 대부분 비대칭(예 `bottom_dweller` head u0.26/l0.38)이라 기존 어류의
  **곡선이 바뀜**(극단점은 동일). upper/lower 의도를 제대로 반영하는 개선 방향이나 시각 변화
  이므로 실제 화면 확인 필요.
- 참고: 머리 dorsal/ventral 프로파일은 여전히 `center_y_delta`+floor로 처리(별개 경로). 추후
  머리 프로파일도 이 egg `hd` 경로로 합치면 솔기 floor 핵 제거 가능(추가 작업).
- **머리/주둥이 링의 높이 동작(조사 후 결정)**: 측정 결과 `head` 링은 이미 reshape 정상
  동작(upper→머리 윗면↑, lower→머리 아래↓). `snout`(맨앞) 링만 머리를 평행이동시킴 —
  머리 세로 스케일 `head_depth_scale`가 `head` 링만 참조하고 `snout`은 머리 중심 샘플만
  흔들기 때문. `snout`도 reshape하려면 머리 세로 크기를 `snout`에 의존시켜야 해 기존 프리셋
  머리 비율이 바뀌므로, **사용자 결정: `head` 링을 머리 세로 프로파일 컨트롤로 사용**하고
  `snout` 링은 현 상태 유지(머리 실루엣 contour에 고정). 추가 코드 변경 없음.

### 내일 할 일 (남은 작업)

0. ~~위 '남은 머리 이슈' 2건 우선 처리(머리 솔기 갈라짐 · 눈 전방 한계).~~ → 완료(위 참고).
1. **Phase 5 본작업(선택)**: 이산 `head_shape`(hump/steep_forehead/flattened)·
   `head_ornament` enum의 baked 변형을 제거하고 연속 파라미터로 단일화 + `ensure_head_parameters`
   신설로 기존 프리셋 매핑. 주의: 현재는 baked + 연속이 가산 공존(저위험)이라 굳이 안 해도 동작.
   진행 시 ShellRigTest/HeadEditorModelTest의 형태 의존 단언과 프리셋 외형 변화 주의.
2. **Phase 6 검증**: 대표 5종(나비고기·쥐치복·나폴레옹·금붕어·아로와나)을 신규 슬라이더만으로
   재현해 보고 부족한 컨트롤 발견·보완.
3. 후보: 좌우 측면 볼혹(금붕어 볼), 혹 복수 개, 부착 메시 방식 혹, 머리 메시 테셀레이션 상향
   (윤곽 1.0 근처 큰 혹에서 각짐), flatten 메시(0.65) vs contour(0.825) 불일치 정리.

## 참고

- 테스트: `tools/run_godot_cli_tests.ps1` (Godot 4.6.2 headless, 37 scenes).
- `HeadProfile`는 전역 `class_name`이 아니라 preload 상수로 참조한다
  (headless 실행이 신규 전역 클래스를 인식하지 못함).
- 신규 머리 파라미터는 모두 중립 기본값(가산식)이라 기존 프리셋 외형 불변.
