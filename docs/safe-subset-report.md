# CSS Safe Subset Report

Properties with high browser compatibility (>= 70% pass rate).

## Tier 1: Safe (>= 80% pass rate)

### text-align
Pass rate: 100.0% (9/9)

Safe values:
  - `center`: 100% (9/9)

### order
Pass rate: 100.0% (3/3)

Safe values:
  - `<number>`: 100% (7/7)

### row-gap
Pass rate: 100.0% (3/3)

Safe values:
  - `<length>`: 100% (3/3)

### print-color-adjust
Pass rate: 100.0% (3/3)

Safe values:
  - `exact`: 100% (3/3)

### will-change
Pass rate: 100.0% (5/5)

Safe values:
  - `transform`: 100% (4/4)

### border-right-width
Pass rate: 100.0% (4/4)

Safe values:
  - `<length>`: 100% (4/4)

### border-right-style
Pass rate: 100.0% (4/4)

Safe values:
  - `solid`: 100% (4/4)

### box-shadow
Pass rate: 100.0% (7/7)

Safe values:
  - `20px 20px 5px red`: 100% (2/2)

### transition-property
Pass rate: 100.0% (3/3)

Safe values:
  - `all`: 100% (2/2)

### transition-duration
Pass rate: 100.0% (3/3)

Safe values:
  - `1s`: 100% (3/3)

### align-content
Pass rate: 96.2% (25/26)

Safe values:
  - `flex-start`: 100% (12/12)
  - `flex-end`: 100% (11/11)
  - `center`: 100% (12/12)
  - `space-between`: 100% (12/12)
  - `space-around`: 100% (11/11)
  - `space-evenly`: 100% (9/9)
  - `end`: 100% (8/8)
  - `stretch`: 100% (3/3)
  - `start`: 90% (9/10)

### flex-shrink
Pass rate: 93.8% (15/16)

Safe values:
  - `<number>`: 96% (27/28)

### z-index
Pass rate: 85.7% (78/91)

Safe values:
  - `<number>`: 85% (94/111)

### border-color
Pass rate: 83.3% (5/6)

Safe values:
  - `orange`: 100% (2/2)
  - `green`: 100% (2/2)

### justify-content
Pass rate: 82.6% (19/23)

Safe values:
  - `flex-start`: 100% (7/7)
  - `flex-end`: 100% (3/3)

### margin-top
Pass rate: 82.5% (47/57)

Safe values:
  - `<length>`: 88% (46/52)

### overflow-y
Pass rate: 80.0% (16/20)

Safe values:
  - `scroll`: 100% (4/4)
  - `clip`: 90% (9/10)
  - `auto`: 80% (4/5)

### border-right-color
Pass rate: 80.0% (4/5)

Safe values:
  - `red`: 100% (4/4)

### overflow-clip-margin
Pass rate: 80.0% (20/25)

Safe values:
  - `border-box 5px`: 100% (2/2)
  - `padding-box 5px`: 100% (2/2)
  - `content-box 5px`: 100% (2/2)
  - `<length>`: 91% (20/22)

## Tier 2: Caution (60-80% pass rate)

### overflow-x
Pass rate: 77.8% (14/18)

### animation-fill-mode
Pass rate: 77.8% (7/9)

### opacity
Pass rate: 75.0% (9/12)

### border-radius
Pass rate: 75.0% (12/16)

### align-self
Pass rate: 70.0% (21/30)

### animation-duration
Pass rate: 70.0% (7/10)

### animation-name
Pass rate: 70.0% (7/10)

### animation-play-state
Pass rate: 70.0% (7/10)

### flex-basis
Pass rate: 69.7% (23/33)

### flex-wrap
Pass rate: 67.3% (33/49)

### background-color
Pass rate: 66.7% (202/303)

### scrollbar-color
Pass rate: 66.7% (4/6)

### grid-template-rows
Pass rate: 64.7% (11/17)

### padding-bottom
Pass rate: 62.5% (5/8)

### flex
Pass rate: 61.0% (75/123)

### position
Pass rate: 60.5% (228/377)

### margin-bottom
Pass rate: 60.0% (24/40)

## Tier 3: Experimental (< 60% pass rate)

- outline: 59.3% (16/27)
- min-height: 58.9% (53/90)
- min-width: 58.1% (43/74)
- flex-grow: 57.9% (11/19)
- height: 57.7% (496/859)
- width: 57.0% (515/903)
- left: 55.6% (74/133)
- top: 55.3% (84/152)
- bottom: 54.5% (24/44)
- margin-left: 54.3% (25/46)
- margin: 53.7% (115/214)
- background: 53.0% (336/634)
- grid-template-columns: 52.9% (9/17)
- border-width: 52.9% (9/17)
- flex-direction: 52.2% (84/161)
- background-image: 50.0% (2/4)
- filter: 50.0% (2/4)
- display: 47.5% (369/777)
- flex-flow: 46.5% (20/43)
- overflow: 45.0% (91/202)
- ... and 67 more

## Summary

Total properties analyzed: 200
Tier 1 (Safe): 19 properties
Tier 2 (Caution): 17 properties
Tier 3 (Experimental): 87 properties