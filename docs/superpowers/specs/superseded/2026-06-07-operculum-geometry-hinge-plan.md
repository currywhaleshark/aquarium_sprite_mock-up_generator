# 아가미덮개(Operculum) 구조 및 애니메이션 개선 사양서

본 사양서는 아가미덮개의 해부학적 정확도를 높이고, 기존 구현에서 드러난 둥둥 떠 있는 외관, 눈 침범 현상, 그리고 어색한 리본형 개폐 애니메이션을 해결하기 위한 구체적인 수정 계획을 담고 있습니다.

## 해결해야 할 핵심 문제점

1. **가짜로 공중에 떠 있는 Gill Slit (아가미 틈)**: 아가미가 열릴 때 내부의 어두운 공동이 노출되는 대신 검은색 리본 메쉬가 아가미판과 함께 공중에 튀어나와 부자연스럽습니다.
2. **눈(Eye) 침범 현상**: 눈 위치 매개변수(`eye_position_x`)를 고려하지 않고 아가미 앞 경계가 고정되어 있어, 눈을 뒤로 배치할 경우 아가미덮개가 눈을 가려버립니다.
3. **지나치게 떠 있는 외관 (Floating Shell)**: 몸통 껍질과의 간섭 회피를 위한 마진(`shell_clear`)이 너무 커서 머리 밀착도가 떨어지고 붕 떠 보입니다.
4. **선형적/직선형 개폐 움직임**: 실제 아가미처럼 앞을 축으로 벌어지는 회전(Hinge)이 아니라 단순 평행 이동 및 뒤쪽 슬라이딩으로 작동하여 딱딱하게 보입니다.

---

## 제안하는 변경 사항 (Proposed Changes)

### 1. 전반적인 아가미 개폐 메커니즘을 물리적 회전(Hinge Pivot)으로 수정
실제 물고기 아가미와 같이 앞쪽 경계(`anterior_x`)를 힌지 축으로 삼아 바깥쪽으로 스윙 회전하도록 공식을 변경합니다.
* **수학적 모델**:
  * 회전각 $\theta$ = `cfg["open"] * 0.22` rad (~12.6도)
  * 앞쪽 경계로부터의 거리 $dx = x - anterior\_x$
  * 회전 적용 후 좌표:
    * $z' = z + side \cdot dx \cdot \sin(\theta)$ (바깥쪽 벌어짐)
    * $x' = x - dx \cdot (1 - \cos(\theta))$ (호 곡선에 따른 소폭 앞쪽 이동)

### 2. Gill Slit을 머리 표면에 고정 (apply_open = false)
* 아가미 틈(`GillSlit`) 리본 메쉬의 개폐 애니메이션 적용 여부(`apply_open`)를 `false`로 변경합니다.
* 이렇게 하면 아가미판(`Opercle`)이 바깥으로 들릴 때, 그 아래 머리 표면에 밀착되어 있는 어두운 새열 리본이 자연스럽게 노출되면서 **깊이감 있는 아가미 구멍(Cavity)** 효과를 냅니다.

### 3. 눈 위치에 따른 아가미 앞 경계의 동적 제어 (Dynamic Eye-Operculum Margin)
* 머리 로컬 X축 상에서 눈의 위치(`eye_local_x`)와 눈의 반지름(`eye_local_radius`)을 계산합니다.
* 아가미덮개의 앞쪽 시작 위치(`anterior_x`)가 항상 눈의 뒤쪽 마진(`eye_local_x + eye_local_radius + 0.06`)보다 뒤에 오도록 동적으로 강제 제한합니다.
* 눈이 뒤로 배치되면 아가미판이 자동으로 작아지거나 뒤로 밀려나 겹침 현상을 원천 방단합니다.

### 4. 몸통 밀착도 정밀 튜닝 (Tight Outset)
* `_operculum_outset` 수식의 계수를 조정하여 몸통 껍질 바로 위에 부드럽게 얹히도록 거리를 최소화합니다.
  * 기존: `shell_clear * lerp(0.86, 1.28, u) + 0.02`
  * 개선: `shell_clear * lerp(0.80, 1.15, u) + 0.008` (유격 대폭 축소)

---

## 컴포넌트별 상세 변경 내역

### [creature] (지느러미 및 리그 엔진)

#### [MODIFY] [FishRig.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/creature/FishRig.gd)
* **`_operculum_params` 함수**:
  * 눈 위치를 감지하여 `min_anterior_x`를 계산하고, `anterior_x = maxf(posterior_x - cover_length, min_anterior_x)` 공식을 통해 눈 겹침을 방지합니다.
* **`_operculum_outset` 함수**:
  * 아가미가 머리/몸통에 더욱 밀착하도록 오프셋 계수를 낮춥니다.
* **`_operculum_plate_mesh` 및 `_operculum_ribbon_mesh` 함수**:
  * 단순 덧셈 기반 개폐 연산을 앞 경계(`anterior_x`) 기준의 삼각함수 물리 회전 공식으로 전면 대체합니다.
* **`_add_operculum_side` 함수**:
  * `GillSlit` 리본 메쉬 생성 시 `apply_open` 매개변수를 `false`로 넘겨 고정 표면 데칼로 만듭니다.

---

## 검증 계획 (Verification Plan)

### 자동화 테스트 (Automated Tests)
* [HeadEditorModelTest.gd](file:///c:/Users/yurib/Documents/New%20project/fish_sprite/scripts/tools/HeadEditorModelTest.gd)를 포함한 아가미 관련 물리 테스트 스위트를 실행하여 회전각 및 최소 안쪽 거리의 유효성을 검증합니다.
```powershell
# 특정 아가미/헤드 테스트 실행
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1 -Filter HeadEditorModelTest
# 전체 단위 테스트 실행
powershell -ExecutionPolicy Bypass -File tools\run_godot_cli_tests.ps1
```

### 수동 검증 (Manual Verification)
1. **눈 위치 변동**: 에디터에서 눈 위치(`eye_position_x`)를 앞뒤로 최대로 움직였을 때 아가미판이 겹치지 않고 자연스럽게 길어지거나 짧아지는지 확인합니다.
2. **아가미 개폐 애니메이션**: 아가미 열기 슬라이더를 최대로 늘렸을 때, 검은색 띠가 튀어나오지 않고 덮개만 자연스럽게 들리며 안쪽의 검은 공동이 노출되는지 입체감을 검증합니다.
3. **밀착도 확인**: 정면 뷰에서 머리와 아가미 판 사이가 너무 벌어져 날개처럼 보이지 않는지 확인합니다.
