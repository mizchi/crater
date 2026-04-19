///|
/// Generated from WPT SVG reftests (static only)
/// Run: node scripts/generate-wpt-svg.mjs

///|
struct WptCase {
  name : String
  test_svg : String
  ref_svg : String
  width : Int
  height : Int
  max_diff : Int
  max_pixels : Int
}

///|
fn wpt_svg_cases() -> Array[WptCase] {
  [
    case(
      "embedded/image-embedding-svg-with-auto-height.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:h="http://www.w3.org/1999/xhtml" viewBox="0 0 3 3" width="200" height="200">
        #|  <metadata>
        #|    <title>&lt;image&gt; embedding SVG image with auto height</title>
        #|    <h:link rel="match" href="reference/green-rect-100x100.svg"/>
        #|  </metadata>
        #|  <image href="data:image/svg+xml,&lt;svg xmlns='http://www.w3.org/2000/svg' width='50' height='50' &gt;&lt;rect width='50' height='50' fill='green'/&gt;&lt;/svg&gt;" width="1.5"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      200,
      200,
      -1,
      -1,
    ),
    case(
      "embedded/image-embedding-svg-with-fractional-viewbox.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>&lt;image&gt; embedding SVG image with fractional viewBox</title>
        #|  <h:link rel="help" href="https://crbug.com/1123047"/>
        #|  <h:link rel="match" href="reference/green-rect-100x100.svg"/>
        #|
        #|  <rect width="100" height="100" fill="red"/>
        #|  <svg viewBox="0 0 200 150" width="100" height="100" preserveAspectRatio="none">
        #|    <image preserveAspectRatio="none" y="-150" width="200" height="300"
        #|           href="data:image/svg+xml,&lt;svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1683.78 1190.55'&gt;&lt;rect width='1696' height='1199' fill='green'/&gt;&lt;/svg&gt;"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "embedded/image-embedding-svg-with-viewport-units-inline-style.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <metadata>
        #|    <title>&lt;image&gt; embedding SVG image with viewport units</title>
        #|    <h:link rel="match" href="reference/green-rect-100x100.svg"/>
        #|  </metadata>
        #|  <image xlink:href="data:image/svg+xml,&lt;svg xmlns='http://www.w3.org/2000/svg'&gt;&lt;rect style='width: 50vw; height: 50vh' fill='green'/&gt;&lt;/svg&gt;"
        #|         width="200" height="200"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "embedded/image-embedding-svg-with-viewport-units.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <metadata>
        #|    <title>&lt;image&gt; embedding SVG image with viewport units</title>
        #|    <h:link rel="match" href="reference/green-rect-100x100.svg"/>
        #|  </metadata>
        #|  <image xlink:href="data:image/svg+xml,&lt;svg xmlns='http://www.w3.org/2000/svg'&gt;&lt;rect width='50vw' height='50vh' fill='green'/&gt;&lt;/svg&gt;"
        #|         width="200" height="200"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "embedded/image-fractional-width-vertical-fidelity.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Vertical fidelity of &#x3c;image&#x3e; element with fractional width</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/embedded.html#ImageElement"/>
        #|  <h:link rel="match" href="reference/green-rect-100x100.svg"/>
        #|  <rect x="95" width="5" height="100" fill="green"/>
        #|  <rect width="95" height="100" fill="red"/>
        #|  <g clip-path="url(#c)">
        #|    <clipPath id="c">
        #|      <rect width="95" height="100"/>
        #|    </clipPath>
        #|    <image href="data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100' preserveAspectRatio='xMinYMin'%3e
        #|                 %3crect width='100' height='100' fill='green'/%3e%3c/svg%3e"
        #|                 width="101.2" height="100"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/color-interpolation-001.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>'color-interpolation: linearRGB' applies somewhat correctly</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#ColorInterpolation"/>
        #|  <h:link rel="match" href="../struct/reftests/reference/green-100x100.svg"/>
        #|
        #|  <rect width="100" height="100" fill="green" color-interpolation="linearRGB"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/currentColor-override-pserver-fallback.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <metadata>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="author" title="Dan Glastonbury" href="mailto:dglastonbury@mozilla.com"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="help" href="https://www.w3.org/TR/SVG2/pservers.html"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="match" href="currentColor-override-pserver-fallback-ref.svg"/>
        #|    <meta xmlns="http://www.w3.org/1999/xhtml" name="assert" content="missing pattern fallback inherits fill color via currentcolor."/>
        #|  </metadata>
        #|
        #|  <g fill="url(#NotFound) currentcolor" color="red">
        #|    <circle color="limegreen" stroke="black" cx="50" cy="50" r="40" />
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <!-- pattern inherits fill color via currentcolor -->
        #|  <circle stroke="black" fill="limegreen" cx="50" cy="50" r="40" />
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/currentColor-override-pserver-fill.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <metadata>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="author" title="Dan Glastonbury" href="mailto:dglastonbury@mozilla.com"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="help" href="https://www.w3.org/TR/SVG2/pservers.html"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="match" href="currentColor-override-pserver-fill-ref.svg"/>
        #|    <meta xmlns="http://www.w3.org/1999/xhtml" name="assert" content="pattern inherits fill color via currentcolor."/>
        #|  </metadata>
        #|
        #|  <defs>
        #|    <pattern id="MyPattern" patternUnits="userSpaceOnUse"
        #|             x="5" y ="5" width="10" height="10" color="red" fill="currentcolor">
        #|      <circle color="limegreen" fill="inherit" cx="5" cy="5" r="5" />
        #|    </pattern>
        #|  </defs>
        #|
        #|  <circle stroke="black" fill="url(#MyPattern)" cx="50" cy="50" r="40" />
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <!-- pattern inherits fill color via currentcolor -->
        #|  <defs>
        #|    <pattern id="MyPattern" patternUnits="userSpaceOnUse"
        #|             x="5" y ="5" width="10" height="10">
        #|      <circle fill="limegreen" cx="5" cy="5" r="5" />
        #|    </pattern>
        #|  </defs>
        #|
        #|  <circle color="blue" stroke="black" fill="url(#MyPattern)" cx="50" cy="50" r="40" />
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/currentColor-override-pserver-stroke.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <metadata>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="author" title="Dan Glastonbury" href="mailto:dglastonbury@mozilla.com"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="help" href="https://www.w3.org/TR/SVG2/pservers.html"/>
        #|    <link xmlns="http://www.w3.org/1999/xhtml" rel="match" href="currentColor-override-pserver-stroke-ref.svg"/>
        #|    <meta xmlns="http://www.w3.org/1999/xhtml" name="assert" content="pattern inherits stroke color via currentcolor."/>
        #|  </metadata>
        #|
        #|  <defs>
        #|    <pattern id="MyPattern" patternUnits="userSpaceOnUse"
        #|             x="5" y ="5" width="10" height="10" color="red" stroke="currentcolor">
        #|      <circle color="limegreen" stroke="inherit" stroke-width="5%" cx="5" cy="5" r="5" />
        #|    </pattern>
        #|  </defs>
        #|
        #|  <circle stroke="black" fill="url(#MyPattern)" cx="50" cy="50" r="40" />
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <!-- pattern inherits fill color via currentcolor -->
        #|  <defs>
        #|    <pattern id="MyPattern" patternUnits="userSpaceOnUse"
        #|             x="5" y ="5" width="10" height="10">
        #|      <circle stroke="limegreen" stroke-width="5%" cx="5" cy="5" r="5" />
        #|    </pattern>
        #|  </defs>
        #|
        #|  <circle stroke="black" fill="url(#MyPattern)" cx="50" cy="50" r="40" />
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/marker-001.svg",
      (
        #|<svg width="300" height="300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <!--
        #|    Tests the basic support for markers.
        #|
        #|    The top test examines the basic support for the marker element and style. The
        #|    markers are purple rectangles.
        #|
        #|    The middle test examines the support for the different styles of marker
        #|    properties. The "marker-start" property defines the marker to use at the first
        #|    vertex of the marked path, in this case a purple rectangle. The "marker-end"
        #|    property defines the marker to use at the last vertex of the marked path, in
        #|    this case a blue triangle. The "marker-mid" property defines the marker to use
        #|    at all vertices, other than the first and last, of the marked path, in this
        #|    case a green circle.
        #|
        #|    The bottom test examines the support for marker orientation along the path
        #|    direction. The second vertex, the top right corner of the path, has a marker
        #|    that is rotated 45 degrees, since that is the average of the horizontal and
        #|    vertical segments each side. The last vertex, the bottom right corner of the
        #|    path, has a marker rotated 90 degrees since that is the direction of the last
        #|    path segment.
        #|    -->
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#Markers"/>
        #|    <html:link rel="match" href="marker-001-ref.svg"/>
        #|    <html:meta name="assert" content="Tests the basic support for markers."/>
        #|    <defs>
        #|      <!-- Define a few simple marker elements -->
        #|      <marker id="marker1" refX="1" refY="1" overflow="visible" >
        #|        <rect width="2" height="2" fill="purple" stroke="none"/>
        #|      </marker>
        #|      <marker id="marker2" orient="auto" refX="1" refY="1" overflow="visible">
        #|        <path d="M 1 0 L 2 2 L 0 2 Z" fill="blue" stroke="none"/>
        #|      </marker>
        #|      <marker id="markerStart" refX="1" refY="1" overflow="visible">
        #|        <rect width="2" height="2" fill="purple" stroke="none"/>
        #|      </marker>
        #|      <marker id="markerMiddle" overflow="visible">
        #|        <circle cx="0" cy="0" r="1" fill="green" stroke="none"/>
        #|      </marker>
        #|      <marker id="markerEnd" refX="1" refY="1" overflow="visible">
        #|        <path d="M 1 0 L 2 2 L 0 2 Z" fill="blue" stroke="none"/>
        #|      </marker>
        #|    </defs>
        #|    <!-- Basic Marker Test -->
        #|    <text x="10" y="30" font-size="14">Basic Markers</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#marker1)" marker-mid="url(#marker1)" marker-end="url(#marker1)" d="M 130 40 L 180 40 L 180 90"/>
        #|    <!-- Start, Middle and End Marker Test -->
        #|    <text x="10" y="115" font-size="14">Start, Middle and End</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#markerStart)" marker-mid="url(#markerMiddle)" marker-end="url(#markerEnd)" d="M 130 135 L 180 135 L 180 185"/>
        #|    <!-- Auto Orientation Marker Test -->
        #|    <text x="10" y="210" font-size="14">Automatic Orientation</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#marker2)" marker-mid="url(#marker2)" marker-end="url(#marker2)" d="M 130 230 L 180 230 L 180 280"/>
        #|</svg>
        #|
      ),
      (
        #|<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
        #|  <text x="10" y="30" font-size="14">Basic Markers</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 40 L 180 40 L 180 90"/>
        #|  <g transform="translate(114,24)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,24)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,74)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|
        #|  <text x="10" y="115" font-size="14">Start, Middle and End</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 135 L 180 135 L 180 185"/>
        #|  <g transform="translate(114,119)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,135)">
        #|    <circle r="16" fill="green" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,169)">
        #|    <path d="M 16 0 L 32 32 L 0 32 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|
        #|  <text x="10" y="210" font-size="14">Automatic Orientation</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 230 L 180 230 L 180 280"/>
        #|  <g transform="translate(130,230) rotate(0)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,230) rotate(45)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,280) rotate(90)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      300,
      -1,
      -1,
    ),
    case(
      "painting/marker-002.svg",
      (
        #|<svg width="500" height="500"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <!--
        #|    Tests the rendering of markers, specifically property inheritance. For the four
        #|    tests, there should be two identical paths with markers drawn.
        #|
        #|    The top two tests examine the rendering of markers when the marker and the path
        #|    referencing it share the same parent and all painting properties are specfied
        #|    on that parent. The first test show inheritance of the 'fill' property and the
        #|    second the inheritance of the 'paint' property. In both tests, the marker is
        #|    painting using the same properties as the referencing object. Because of
        #|    scaling transformations on the marker, the stroke on the second test is thinner
        #|    than on the referencing object.
        #|
        #|    The third and fourth tests examine the rendering of markers in a situation
        #|    where the marker and referencing path do NOT share the same parent and painting
        #|    properties are specified both on the parent of the marked path and on the
        #|    contents of the marker itself. In both cases, the marker's parent specifies
        #|    fill="green" stroke="blue" stroke-width="8". For the third test, the marker
        #|    contents override with stroke="black". For the fourth test, the marker contents
        #|    override with fill="black". In neither case should you see fill="orange" or
        #|    stroke="blue" or "stroke="purple" on the markers as these properties are
        #|    specified on the ancestor of the referencing object or the referencing object
        #|    itself and thus shouldn't affect the marker.
        #|    -->
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#Markers"/>
        #|    <html:link rel="match" href="marker-002-ref.svg"/>
        #|    <html:meta name="assert" content="Tests property inheritance when rendering markers."/>
        #|    <g fill="green">
        #|      <text x="125" y="30" font-size="14" fill="black">Marker Rendering Properties</text>
        #|      <!-- Fill property -->
        #|      <g fill="black" stroke="none" stroke-width="8">
        #|        <marker id="marker1" viewBox="0 0 10 10" markerWidth="2" markerHeight="2" refX="5" refY="5" markerUnits="strokeWidth">
        #|          <rect width="10" height="10"/>
        #|        </marker>
        #|        <text x="100" y="140" font-size="10" fill="black" stroke="none">Fill Property</text>
        #|        <path marker-start="url(#marker1)" marker-mid="url(#marker1)" marker-end="url(#marker1)" d="M 30 60 L 80 60 L 80 110 Z"/>
        #|      </g>
        #|      <!-- Stroke property -->
        #|      <g fill="none" stroke="black" stroke-width="4">
        #|        <marker id="marker2" viewBox="0 0 20 20" markerWidth="4" markerHeight="4" refX="10" refY="10" markerUnits="strokeWidth">
        #|          <rect width="20" height="20"/>
        #|        </marker>
        #|        <text x="340" y="140" font-size="10" fill="black" stroke="none">Stroke Property</text>
        #|        <path marker-start="url(#marker2)" marker-mid="url(#marker2)" marker-end="url(#marker2)" d="M 270 60 L 320 60 L 320 110 Z"/>
        #|      </g>
        #|      <!-- Define marker element with parents setting painting properties -->
        #|      <g fill="green" stroke="blue" stroke-width="8">
        #|        <marker id="marker3" viewBox="0 0 20 20" markerWidth="4" markerHeight="4" refX="10" refY="10" markerUnits="strokeWidth">
        #|          <rect width="20" height="20" stroke="black"/>
        #|        </marker>
        #|        <marker id="marker4" viewBox="0 0 10 10" markerWidth="4" markerHeight="4" refX="5" refY="5" markerUnits="strokeWidth">
        #|          <rect width="10" height="10" fill="black" stroke-width="4"/>
        #|        </marker>
        #|      </g>
        #|      <!-- Parent and specified properties -->
        #|      <g fill="orange" stroke="blue">
        #|        <text x="90" y="270" font-size="10" fill="black" stroke="none">Mixed Properties</text>
        #|        <path stroke="purple" stroke-width="4" marker-start="url(#marker3)" marker-mid="url(#marker3)" marker-end="url(#marker3)" d="M 30 190 L 80 190 L 80 240 Z"/>
        #|      </g>
        #|      <g fill="orange" stroke="green">
        #|        <text x="340" y="270" font-size="10" fill="black" stroke="none">Mixed Properties</text>
        #|        <path stroke="purple" stroke-width="4" marker-start="url(#marker4)" marker-mid="url(#marker4)" marker-end="url(#marker4)" d="M 270 190 L 320 190 L 320 240 Z"/>
        #|      </g>
        #|    </g>
        #|</svg>
        #|
      ),
      (
        #|<svg width="500" height="500"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <g>
        #|      <text x="125" y="30" font-size="14" fill="black">Marker Rendering Properties</text>
        #|      <!-- Fill property -->
        #|      <g>
        #|        <marker id="marker1" viewBox="0 0 10 10" markerWidth="2" markerHeight="2" refX="5" refY="5" markerUnits="strokeWidth">
        #|          <rect width="10" height="10" fill="black" stroke="none" stroke-width="8"/>
        #|        </marker>
        #|        <text x="100" y="140" font-size="10" fill="black" stroke="none">Fill Property</text>
        #|        <path marker-start="url(#marker1)" marker-mid="url(#marker1)" marker-end="url(#marker1)" d="M 30 60 L 80 60 L 80 110 Z"
        #|            fill="black" stroke="none" stroke-width="8"/>
        #|      </g>
        #|      <!-- Stroke property -->
        #|      <g>
        #|        <marker id="marker2" viewBox="0 0 20 20" markerWidth="4" markerHeight="4" refX="10" refY="10" markerUnits="strokeWidth">
        #|          <rect width="20" height="20" fill="none" stroke="black" stroke-width="4"/>
        #|        </marker>
        #|        <text x="340" y="140" font-size="10" fill="black" stroke="none">Stroke Property</text>
        #|        <path marker-start="url(#marker2)" marker-mid="url(#marker2)" marker-end="url(#marker2)" d="M 270 60 L 320 60 L 320 110 Z"
        #|            fill="none" stroke="black" stroke-width="4"/>
        #|      </g>
        #|      <!-- Define marker element with parents setting painting properties -->
        #|      <g>
        #|        <marker id="marker3" viewBox="0 0 20 20" markerWidth="4" markerHeight="4" refX="10" refY="10" markerUnits="strokeWidth">
        #|          <rect width="20" height="20" stroke="black" fill="green" stroke-width="8"/>
        #|        </marker>
        #|        <marker id="marker4" viewBox="0 0 10 10" markerWidth="4" markerHeight="4" refX="5" refY="5" markerUnits="strokeWidth">
        #|          <rect width="10" height="10" fill="black" stroke-width="4" stroke="blue"/>
        #|        </marker>
        #|      </g>
        #|      <!-- Parent and specified properties -->
        #|      <g>
        #|        <text x="90" y="270" font-size="10" fill="black" stroke="none">Mixed Properties</text>
        #|        <path stroke="purple" stroke-width="4" marker-start="url(#marker3)" marker-mid="url(#marker3)" marker-end="url(#marker3)" d="M 30 190 L 80 190 L 80 240 Z" fill="orange"/>
        #|      </g>
        #|      <g>
        #|        <text x="340" y="270" font-size="10" fill="black" stroke="none">Mixed Properties</text>
        #|        <path stroke="purple" stroke-width="4" marker-start="url(#marker4)" marker-mid="url(#marker4)" marker-end="url(#marker4)" d="M 270 190 L 320 190 L 320 240 Z" fill="orange"/>
        #|      </g>
        #|    </g>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "painting/marker-004.svg",
      (
        #|<svg width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <!--
        #|    The SVG specification defines three properties to reference markers: marker-start, marker-mid,
        #|    marker-end. It also provides a shorthand property,marker.  Using the marker property from a style sheet
        #|    is equivalent to using all three (start, mid, end). However, shorthand properties cannot be used as presentation attributes.
        #|    -->
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#Markers"/>
        #|    <html:link rel="match" href="marker-004-ref.svg"/>
        #|    <html:meta name="assert" content="Tests marker property."/>
        #|    <defs>
        #|      <marker id="marker2" markerUnits="strokeWidth" refX="100" refY="100" markerWidth="15" markerHeight="15" viewBox="0 0 200 200">
        #|        <rect width="200" height="200" fill="red" stroke="none"/>
        #|      </marker>
        #|    </defs>
        #|
        #|    <text font-size="20" x="240" y="28" text-anchor="middle">'marker' attribute test</text>
        #|    <!-- There is no marker attribute so no markers should be applied. -->
        #|    <g marker="url(#marker2)" fill="gold" stroke="black" fill-rule="evenodd" transform="translate(50,20)">
        #|      <path d="M10,60 Q90,60 90,140 Q10,140 10,60 Z M10,140 Q10,60 90,60 Q90,140 10,140 Z M50,70 L80,100 50,130 20,100 Z"/>
        #|      <polygon points="100,60 120,140 140,60 160,140 180,60 180,100 100,100"/>
        #|      <polyline points="190,60 210,140 230,60 250,140 270,60 270,100 190,100"/>
        #|      <line x1="280" x2="370" y1="60" y2="140"/>
        #|      <line x1="370" x2="280" y1="60" y2="140"/>
        #|    </g>
        #|</svg>
        #|
      ),
      (
        #|<svg width="100%" height="100%" viewBox="0 0 480 360" xmlns="http://www.w3.org/2000/svg">
        #|    <text font-size="20" x="240" y="28" text-anchor="middle">'marker' attribute test</text>
        #|    <g fill="gold" stroke="black" fill-rule="evenodd" transform="translate(50,20)">
        #|      <path d="M10,60 Q90,60 90,140 Q10,140 10,60 Z M10,140 Q10,60 90,60 Q90,140 10,140 Z M50,70 L80,100 50,130 20,100 Z"/>
        #|      <polygon points="100,60 120,140 140,60 160,140 180,60 180,100 100,100"/>
        #|      <polyline points="190,60 210,140 230,60 250,140 270,60 270,100 190,100"/>
        #|      <line x1="280" x2="370" y1="60" y2="140"/>
        #|      <line x1="370" x2="280" y1="60" y2="140"/>
        #|    </g>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/marker-006.svg",
      (
        #|<svg width="300" height="300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <!--
        #|    Tests the basic support for markers. For the three tests, there should be two
        #|    identical paths with markers drawn. The path on the left is rendered using the
        #|    marker elements. The path on the right is rendered using the equivalent SVG,
        #|    showing what the marked path should look like.
        #|
        #|    This test is similar to the marker-001.svg test, but has some viewBox
        #|    attributes that have a non-zero offset.
        #|
        #|    The top test examines the basic support for the marker element and style. The
        #|    markers are purple rectangles.
        #|
        #|    The middle test examines the support for the different styles of marker
        #|    properties. The "marker-start" property defines the marker to use at the first
        #|    vertex of the marked path, in this case a purple rectangle. The "marker-end"
        #|    property defines the marker to use at the last vertex of the marked path, in
        #|    this case a blue triangle. The "marker-mid" property defines the marker to use
        #|    at all vertices, other than the first and last, of the marked path, in this
        #|    case a green circle.
        #|
        #|    The bottom test examines the support for marker orientation along the path
        #|    direction. The second vertex, the top right corner of the path, has a marker
        #|    that is rotated 45 degrees, since that is the average of the horizontal and
        #|    vertical segments each side. The last vertex, the bottom right corner of the
        #|    path, has a marker rotated 90 degrees since that is the direction of the last
        #|    path segment.
        #|    -->
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#Markers"/>
        #|    <html:link rel="match" href="marker-006-ref.svg"/>
        #|    <html:meta name="assert" content="Support for marker viewBox."/>
        #|    <defs>
        #|        <!-- Define a few simple marker elements -->
        #|        <marker id="marker1" viewBox="20 20 10 10" markerWidth="2" markerHeight="2" refX="25" refY="25" markerUnits="strokeWidth">
        #|            <rect x="20" y="20" width="10" height="10" fill="purple" stroke="none"/>
        #|        </marker>
        #|        <marker id="marker2" viewBox="-5 -5 10 10" markerWidth="2" markerHeight="2" markerUnits="strokeWidth" orient="auto">
        #|            <path d="M 0 -5 L 5 5 L -5 5 Z" fill="blue" stroke="none"/>
        #|        </marker>
        #|        <marker id="markerStart" viewBox="0 0 10 10" markerWidth="2" markerHeight="2" refX="5" refY="5" markerUnits="strokeWidth">
        #|            <rect width="10" height="10" fill="purple" stroke="none"/>
        #|        </marker>
        #|        <marker id="markerMiddle" viewBox="0 0 10 10" markerWidth="2" markerHeight="2" refX="5" refY="5" markerUnits="strokeWidth">
        #|            <circle cx="5" cy="5" r="5" fill="green" stroke="none"/>
        #|        </marker>
        #|        <marker id="markerEnd" viewBox="0 0 10 10" markerWidth="2" markerHeight="2" refX="5" refY="5" markerUnits="strokeWidth">
        #|            <path d="M 5 0 L 10 10 L 0 10 Z" fill="blue" stroke="none"/>
        #|        </marker>
        #|    </defs>
        #|    <!-- Basic Marker Test -->
        #|    <text x="10" y="30" font-size="14">Basic Markers</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#marker1)" marker-mid="url(#marker1)" marker-end="url(#marker1)" d="M 130 40 L 180 40 L 180 90"/>
        #|    <!-- Start, Middle and End Marker Test -->
        #|    <text x="10" y="115" font-size="14">Start, Middle and End</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#markerStart)" marker-mid="url(#markerMiddle)" marker-end="url(#markerEnd)" d="M 130 135 L 180 135 L 180 185"/>
        #|    <!-- Auto Orientation Marker Test -->
        #|    <text x="10" y="210" font-size="14">Automatic Orientation</text>
        #|    <path fill="none" stroke="black" stroke-width="16" marker-start="url(#marker2)" marker-mid="url(#marker2)" marker-end="url(#marker2)" d="M 130 230 L 180 230 L 180 280"/>
        #|</svg>
        #|
      ),
      (
        #|<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
        #|  <text x="10" y="30" font-size="14">Basic Markers</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 40 L 180 40 L 180 90"/>
        #|  <g transform="translate(114,24)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,24)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,74)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|
        #|  <text x="10" y="115" font-size="14">Start, Middle and End</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 135 L 180 135 L 180 185"/>
        #|  <g transform="translate(114,119)">
        #|    <rect width="32" height="32" fill="purple" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,135)">
        #|    <circle r="16" fill="green" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(164,169)">
        #|    <path d="M 16 0 L 32 32 L 0 32 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|
        #|  <text x="10" y="210" font-size="14">Automatic Orientation</text>
        #|  <path fill="none" stroke="black" stroke-width="16" d="M 130 230 L 180 230 L 180 280"/>
        #|  <g transform="translate(130,230) rotate(0)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,230) rotate(45)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|  <g transform="translate(180,280) rotate(90)">
        #|    <path d="M 0 -16 L 16 16 L -16 16 Z" fill="blue" stroke="none"/>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      300,
      -1,
      -1,
    ),
    case(
      "painting/marker-007.svg",
      (
        #|<svg width="300" height="300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|    <!--
        #|    A 'marker' element with 'display' set to 'none' on that
        #|    element or any ancestor is rendered when referenced by another element.
        #|    -->
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#Markers"/>
        #|    <html:link rel="match" href="marker-007-ref.svg"/>
        #|    <html:meta name="assert" content="Test marker element with 'display' set to 'none' is rendered when referenced."/>
        #|    <html:meta name="fuzzy" content="maxDifference=0-1; totalPixels=0-10"/>
        #|    <defs>
        #|        <marker id="testMarker" markerWidth="100" markerHeight="100" display="none">
        #|            <path d="M 0 0 L 200 200 L 0 150 z" fill="green" />
        #|        </marker>
        #|        <g display="none">
        #|          <marker id="testMarker2" markerWidth="100" markerHeight="100">
        #|            <path d="M 0 0 L 200 200 L 0 150 z" fill="green" />
        #|          </marker>
        #|        </g>
        #|    </defs>
        #|    <path d="M 0 0 L 25 25" marker-end="url(#testMarker)" />
        #|    <path d="M 100 0 L 125 25" marker-end="url(#testMarker2)" />
        #|</svg>
        #|
      ),
      (
        #|<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
        #|    <path d="M 25 25 v100 h100 z" fill="green" />
        #|    <path d="M 125 25 v100 h100 z" fill="green" />
        #|</svg>
        #|
      ),
      300,
      300,
      1,
      10,
    ),
    case(
      "painting/marker-009.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml" width="500" height="500">
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#OrientAttribute"/>
        #|    <html:link rel="match" href="marker-009-ref.svg"/>
        #|    <html:meta name="assert" content="Tests correct number of markers are drawn on multiple sub-paths"/>
        #|    <html:meta name="fuzzy" content="maxDifference=0-2;totalPixels=0-50"/>
        #|    <defs>
        #|        <marker id="m1" markerUnits="userSpaceOnUse" overflow="visible">
        #|            <circle cx="0" cy="0" r="25" fill="green"/>
        #|        </marker>
        #|        <marker id="m2" markerUnits="userSpaceOnUse" overflow="visible">
        #|            <circle cx="0" cy="0" r="20" fill="skyblue" opacity="0.9"/>
        #|        </marker>
        #|        <marker id="m3" markerUnits="userSpaceOnUse" overflow="visible">
        #|            <circle cx="0" cy="0" r="15" fill="maroon" opacity="0.85"/>
        #|        </marker>
        #|    </defs>
        #|
        #|    <path d="M50,50 h100 v100 z m150,0 h100 v100 z m150,0 h100 v100 z"
        #|    fill="none" stroke="black" stroke-width="10"
        #|    marker-start="url(#m1)"
        #|    marker-mid="url(#m2)"
        #|    marker-end="url(#m3)"
        #|    />
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500">
        #|    <path d="M50,50 h100 v100 z m150,0 h100 v100 z m150,0 h100 v100 z"
        #|    fill="none" stroke="black" stroke-width="10"
        #|    />
        #|    <circle cx="50" cy="50" r="25" fill="green"/>
        #|    <circle cx="50" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="150" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="150" cy="150" r="20" fill="skyblue" opacity="0.9"/>
        #|
        #|    <circle cx="200" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="200" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="300" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="300" cy="150" r="20" fill="skyblue" opacity="0.9"/>
        #|
        #|    <circle cx="350" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="350" cy="50" r="15" fill="maroon" opacity="0.85"/>
        #|    <circle cx="450" cy="50" r="20" fill="skyblue" opacity="0.9"/>
        #|    <circle cx="450" cy="150" r="20" fill="skyblue" opacity="0.9"/>
        #|</svg>
        #|
      ),
      500,
      500,
      2,
      50,
    ),
    case(
      "painting/marker-orient-001.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml" width="500" height="500">
        #|    <html:link rel="help" href="https://www.w3.org/TR/2016/CR-SVG2-20160915/painting.html#OrientAttribute"/>
        #|    <html:link rel="match" href="marker-orient-001-ref.svg"/>
        #|    <html:meta name="assert" content="Ensure orientation of auto and auto-start-reverse markers is correct."/>
        #|    <defs>
        #|        <marker id="arrow" orient="auto-start-reverse" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|     </defs>
        #|    <!-- Test path, with markers -->
        #|    <path d="M 40,40 l140,140 240,240" marker-start="url(#arrow)" marker-mid="url(#arrow)" marker-end="url(#arrow)" stroke="black" stroke-width="2"/>
        #|    <path d="M 40,400 l100,-100 100,-100" marker-start="url(#arrow)" marker-mid="url(#arrow)" marker-end="url(#arrow)" stroke="black" stroke-width="2"/>
        #|    <path d="M 160,40 c40,0 40,0 40,40" marker-start="url(#arrow)" marker-mid="url(#arrow)" marker-end="url(#arrow)" stroke="black" fill="none" stroke-width="2"/>
        #|    <path d="M 260,140 a 100,100 0 1 1 100,100" marker-start="url(#arrow)" marker-mid="url(#arrow)" marker-end="url(#arrow)" stroke="black" fill="none" stroke-width="2"/>
        #|    <path d="M 340,100 h50 v50 h-50 z" marker-start="url(#arrow)" marker-mid="url(#arrow)" marker-end="url(#arrow)" stroke="black" fill="none" stroke-width="2"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500">
        #|    <defs>
        #|        <marker id="arrowNW" orient="225" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowNE" orient="315" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowSE" orient="45" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowSW" orient="135" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowW" orient="180" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowS" orient="90" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|        <marker id="arrowAuto" orient="auto" markerUnits="userSpaceOnUse" style="overflow:visible">
        #|            <path d="M25,0 L 0,-25 L0,25 z" fill="green"/>
        #|        </marker>
        #|     </defs>
        #|    <!-- Test path, with markers -->
        #|    <path d="M 40,40 l140,140 240,240" marker-start="url(#arrowNW)" marker-mid="url(#arrowSE)" marker-end="url(#arrowSE)" stroke="black" stroke-width="2"/>
        #|    <path d="M 40,400 l100,-100 100,-100" marker-start="url(#arrowSW)" marker-mid="url(#arrowNE)" marker-end="url(#arrowNE)" stroke="black" stroke-width="2"/>
        #|    <path d="M 160,40 c40,0 40,0 40,40" marker-start="url(#arrowW)" marker-end="url(#arrowS)" stroke="black" fill="none" stroke-width="2"/>
        #|    <path d="M 260,140 a 100,100 0 1 1 100,100" marker-start="url(#arrowS)" marker-end="url(#arrowW)" stroke="black" fill="none" stroke-width="2"/>
        #|    <path d="M 340,100 h50 v50 h-50 z" marker-start="url(#arrowSW)" marker-mid="url(#arrowAuto)" marker-end="url(#arrowNE)" stroke="black" fill="none" stroke-width="2"/>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "painting/reftests/fallback-001.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>SVG paint server: without fallback color nothing is painted</title>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <rect width="100" height="100" fill="url(#null)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/reftests/fallback-002.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>SVG paint server: paint fallback color</title>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|  <rect width="100" height="100" fill="url(#null) green"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/reftests/gradient-external-reference.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|<defs>
        #|<pattern id="greenPattern" viewBox="0 0 1 1" width="1" height="1">
        #|    <rect width="1" height="1" fill="green"/>
        #|  </pattern>
        #|  <linearGradient id="greenGradient">
        #|    <stop stop-color="green"/>
        #|  </linearGradient>
        #|  <linearGradient id="redGradient">
        #|    <stop stop-color="red"/>
        #|  </linearGradient>
        #|  <marker id="greenMarkerOrient0" orient="0"
        #|          markerWidth="10" markerHeight="10" refX="5" refY="5">
        #|    <rect width="10" height="10" fill="green"/>
        #|  </marker>
        #|</defs>
        #|  <title>External file reference for gradient</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#SpecifyingFillPaint"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#SpecifyingStrokePaint"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/pservers.html#Gradients"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/linking.html#URLReference"/>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|
        #|  <rect width="100" height="100" fill="url(#greenGradient) red"/>
        #|  <rect x="25" y="25" width="50" height="50" fill="none" stroke-width="20"
        #|        stroke="url(#greenGradient) orange"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-external-reference.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|<defs>
        #|<pattern id="greenPattern" viewBox="0 0 1 1" width="1" height="1">
        #|    <rect width="1" height="1" fill="green"/>
        #|  </pattern>
        #|  <linearGradient id="greenGradient">
        #|    <stop stop-color="green"/>
        #|  </linearGradient>
        #|  <linearGradient id="redGradient">
        #|    <stop stop-color="red"/>
        #|  </linearGradient>
        #|  <marker id="greenMarkerOrient0" orient="0"
        #|          markerWidth="10" markerHeight="10" refX="5" refY="5">
        #|    <rect width="10" height="10" fill="green"/>
        #|  </marker>
        #|</defs>
        #|  <title>External file reference for marker</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#VertexMarkerProperties"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/linking.html#URLReference"/>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|
        #|  <path d="M25,25h50v50h-50" fill="none" stroke="red" stroke-width="5"
        #|        marker-start="url(#greenMarkerOrient0)"
        #|        marker-mid="url(#greenMarkerOrient0)"
        #|        marker-end="url(#greenMarkerOrient0)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-path-001.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-001-ref.svg" />
        #|    <html:meta name="fuzzy" content="0-15;0-49"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m 50,120   50,0    50,0     50,0"/>
        #|    <path d="m 50,140   50,20   50,-20   50,20"/>
        #|
        #|    <path d="m 50,200 l 50,0  l 50,0   l 50,0"/>
        #|    <path d="m 50,220 l 50,20 l 50,-20 l 50,20"/>
        #|
        #|    <path d="m 50,280 h 50 v 50 h 50"/>
        #|
        #|    <path d="M 290,120   340,120   390,120   440,120"/>
        #|    <path d="M 290,140   340,160   390,140   440,160"/>
        #|
        #|    <path d="M 290,200 L 340,200 L 390,200 L 440,200"/>
        #|    <path d="M 290,220 L 340,240 L 390,220 L 440,240"/>
        #|
        #|    <path d="M 290,280 H 340 V 330 H 390"/>
        #|</g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="10"
        #|            markerHeight="10"
        #|            orient="auto"
        #|            overflow="visible"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|
        #|    <path id="PStart" transform="matrix(2,0,0,2,0,-10)" d="M 0 0 L 10 5 L 0 10 z" fill="green"/>
        #|    <path id="PMid"   transform="matrix(2,0,0,2,0,-10)" d="M 0 0 L 10 5 L 0 10 z" fill="orange"/>
        #|    <path id="PEnd"   transform="matrix(2,0,0,2,0,-10)" d="M 0 0 L 10 5 L 0 10 z" fill="blue"/>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 50,120   50,0    50,0     50,0"/>
        #|    <path d="m 50,140   50,20   50,-20   50,20"/>
        #|
        #|    <path d="m 50,200 l 50,0  l 50,0   l 50,0"/>
        #|    <path d="m 50,220 l 50,20 l 50,-20 l 50,20"/>
        #|
        #|    <path d="m 50,280 h 50 v 50 h 50"/>
        #|
        #|    <path d="M 290,120   340,120   390,120   440,120"/>
        #|    <path d="M 290,140   340,160   390,140   440,160"/>
        #|
        #|    <path d="M 290,200 L 340,200 L 390,200 L 440,200"/>
        #|    <path d="M 290,220 L 340,240 L 390,220 L 440,240"/>
        #|
        #|    <path d="M 290,280 H 340 V 330 H 390"/>
        #|
        #|    <g id="ref" style="stroke:none">
        #|      <g id="linear">
        #|        <use xlink:href="#PStart" transform="translate(50,120)"/>
        #|        <use xlink:href="#PMid"   transform="translate(100,120)"/>
        #|        <use xlink:href="#PMid"   transform="translate(150,120)"/>
        #|        <use xlink:href="#PEnd"   transform="translate(200,120)"/>
        #|      </g>
        #|      <g id="zigzag">
        #|        <path d="m 50,140 50,20"        style="marker-start:url(#Start)"/>
        #|        <path d="m 50,160 50,0 50,0"    style="marker-mid:url(#Mid)"/>
        #|        <path d="m 100,140 50,0 50,0"   style="marker-mid:url(#Mid)"/>
        #|        <path d="m 150,140 50,20"       style="marker-end:url(#End)"/>
        #|      </g>
        #|      <g id="step">
        #|        <path d="m 50,280 50,0"         style="marker-start:url(#Start)"/>
        #|        <path d="m 50,230 50,50 50,50"  style="marker-mid:url(#Mid)"/>
        #|        <path d="m 50,280 50,50 50,50"  style="marker-mid:url(#Mid)"/>
        #|        <path d="m 100,330 50,0"        style="marker-end:url(#End)"/>
        #|      </g>
        #|
        #|      <use xlink:href="#linear"  transform="translate(0,80)"/>
        #|      <use xlink:href="#zigzag"  transform="translate(0,80)"/>
        #|    </g>
        #|
        #|    <use xlink:href="#ref" transform="translate(240,0)"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      15,
      49,
    ),
    case(
      "painting/reftests/marker-path-002.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-002-ref.svg" />
        #|    <html:meta name="fuzzy" content="0-7;0-935" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m 50,120  c 20,20 30,-20 50,0 c 20,20 30,-20 50,0 c 20,20 30,-20 50,0"/>
        #|    <path d="m 50,150  c 20,20 30,-20 50,0 s       30,-20 50,0 s       30,-20 50,0"/>
        #|
        #|    <path d="m 50,240  q 25,25 50,0  q 25,-25 50,0  q 25,25 50,0"/>
        #|    <path d="m 50,270  q 25,25 50,0  t        50,0  t       50,0"/>
        #|
        #|    <path d="M 290,120 C 310,140 320,100, 340,120 C 360,140 370,100 390,120 C 410,140 420,100 440,120"/>
        #|    <path d="M 290,150 C 310,170 320,130, 340,150 S         370,130 390,150 S         420,130 440,150"/>
        #|
        #|    <path d="M 290,240 Q 315,265 340,240  Q 365,215 390,240  Q 415,265 440,240"/>
        #|    <path d="M 290,270 Q 315,295 340,270  T         390,270  T         440,270"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 50,120  c 20,20 30,-20 50,0 c 20,20 30,-20 50,0 c 20,20 30,-20 50,0"/>
        #|    <path d="m 50,150  c 20,20 30,-20 50,0 s       30,-20 50,0 s       30,-20 50,0"/>
        #|
        #|    <path d="m 50,240  q 25,25 50,0  q 25,-25 50,0  q 25,25 50,0"/>
        #|    <path d="m 50,270  q 25,25 50,0  t        50,0  t       50,0"/>
        #|
        #|    <path d="M 290,120 C 310,140 320,100, 340,120 C 360,140 370,100 390,120 C 410,140 420,100 440,120"/>
        #|    <path d="M 290,150 C 310,170 320,130, 340,150 S         370,130 390,150 S         420,130 440,150"/>
        #|
        #|    <path d="M 290,240 Q 315,265 340,240  Q 365,215 390,240  Q 415,265 440,240"/>
        #|    <path d="M 290,270 Q 315,295 340,270  T         390,270  T         440,270"/>
        #|
        #|    <g id="cubic">
        #|      <path d="m  50,120 20,20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,120 20,20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,120 20,20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,120 20,20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#cubic"  transform="translate(240,  0)"/>
        #|    <use xlink:href="#cubic"  transform="translate(  0, 30)"/>
        #|    <use xlink:href="#cubic"  transform="translate(240, 30)"/>
        #|
        #|    <g id="quadratic">
        #|      <path d="m  50,240 20, 20"  style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,240 20,-20"  style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,240 20, 20"  style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,240 20,-20"  style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#quadratic"  transform="translate(240,  0)"/>
        #|    <use xlink:href="#quadratic"  transform="translate(  0, 30)"/>
        #|    <use xlink:href="#quadratic"  transform="translate(240, 30)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      7,
      935,
    ),
    case(
      "painting/reftests/marker-path-003.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-003-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m  50,120  a 30,20 90 0 0 50,0  a 30,20 90 0 1 50,0  a 30,20 90 0 0 50,0"/>
        #|
        #|    <path d="m  50,240  a 30,20 90 0 1 50,0  a 30,20 90 0 0 50,0  a 30,20 90 0 1 50,0"/>
        #|
        #|    <path d="M 290,120  A 30,20 90 0 0 340,120  A 30,20 90 0 1 390,120  A 30,20 90 0 0 440,120"/>
        #|
        #|    <path d="M 290,240  A 30,20 90 0 1 340,240  A 30,20 90 0 0 390,240  A 30,20 90 0 1 440,240"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m  50,120  a 30,20 90 0 0 50,0  a 30,20 90 0 1 50,0  a 30,20 90 0 0 50,0"/>
        #|
        #|    <path d="m  50,240  a 30,20 90 0 1 50,0  a 30,20 90 0 0 50,0  a 30,20 90 0 1 50,0"/>
        #|
        #|    <path d="M 290,120  A 30,20 90 0 0 340,120  A 30,20 90 0 1 390,120  A 30,20 90 0 0 440,120"/>
        #|
        #|    <path d="M 290,240  A 30,20 90 0 1 340,240  A 30,20 90 0 0 390,240  A 30,20 90 0 1 440,240"/>
        #|
        #|    <g id="down">
        #|      <path d="m  50,120 0, 20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,120 0,-20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,120 0, 20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,120 0,-20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#down"  transform="translate(240,  0)"/>
        #|
        #|    <g id="up">
        #|      <path d="m  50,240 0,-20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,240 0, 20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,240 0,-20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,240 0, 20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#up"  transform="translate(240,  0)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-path-011.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-011-ref.svg" />
        #|    <html:meta name="fuzzy" content="0-3;0-3" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m 50,120   50,0  m 50,0     50,0"/>
        #|    <path d="m 50,140   50,20 m 50,-20   50,20"/>
        #|
        #|    <path d="m 50,200 l 50,0  m 50,0   l 50,0"/>
        #|    <path d="m 50,220 l 50,20 m 50,-20 l 50,20"/>
        #|
        #|    <path d="m 50,280 h 50 m 0,50 h 50"/>
        #|
        #|    <path d="M 290,120   340,120 M 390,120   440,120"/>
        #|    <path d="M 290,140   340,160 M 390,140   440,160"/>
        #|
        #|    <path d="M 290,200 L 340,200 M 390,200 L 440,200"/>
        #|    <path d="M 290,220 L 340,240 M 390,220 L 440,240"/>
        #|
        #|    <path d="M 290,280 H 340 M 340,330 H 390"/>
        #|</g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 50,120   50,0  m 50,0     50,0"/>
        #|    <path d="m 50,140   50,20 m 50,-20   50,20"/>
        #|
        #|    <path d="m 50,200 l 50,0  m 50,0   l 50,0"/>
        #|    <path d="m 50,220 l 50,20 m 50,-20 l 50,20"/>
        #|
        #|    <path d="m 50,280 h 50 m 0,50 h 50"/>
        #|
        #|    <path d="M 290,120   340,120 M 390,120   440,120"/>
        #|    <path d="M 290,140   340,160 M 390,140   440,160"/>
        #|
        #|    <path d="M 290,200 L 340,200 M 390,200 L 440,200"/>
        #|    <path d="M 290,220 L 340,240 M 390,220 L 440,240"/>
        #|
        #|    <path d="M 290,280 H 340 M 340,330 H 390"/>
        #|
        #|    <g id="linear">
        #|      <path d="m  50,120 50,0"    style="stroke:none;marker-start:url(#Start);marker-end:url(#Mid)"/>
        #|      <path d="m 150,120 50,0"    style="stroke:none;marker-start:url(#Mid);  marker-end:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#linear"  transform="translate(240,  0)"/>
        #|    <use xlink:href="#linear"  transform="translate(  0, 80)"/>
        #|    <use xlink:href="#linear"  transform="translate(240, 80)"/>
        #|
        #|    <g id="zigzag">
        #|      <path d="m  50,140 50,20"   style="stroke:none;marker-start:url(#Start);marker-end:url(#Mid)"/>
        #|      <path d="m 150,140 50,20"   style="stroke:none;marker-start:url(#Mid);  marker-end:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#zigzag"  transform="translate(240,  0)"/>
        #|    <use xlink:href="#zigzag"  transform="translate(  0, 80)"/>
        #|    <use xlink:href="#zigzag"  transform="translate(240, 80)"/>
        #|
        #|    <g id="step">
        #|      <path d="m  50,280 50,0"    style="stroke:none;marker-start:url(#Start);marker-end:url(#Mid)"/>
        #|      <path d="m 100,330 50,0"    style="stroke:none;marker-start:url(#Mid);  marker-end:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#step"  transform="translate(240,  0)"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      3,
      3,
    ),
    case(
      "painting/reftests/marker-path-012.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-012-ref.svg" />
        #|    <html:meta name="fuzzy" content="0-7;0-14" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m 50,120  c 20,20 30,-20 50,0 m 50,0 c 20,20 30,-20 50,0"/>
        #|
        #|    <path d="m 50,240  q 25,25 50,0  m 50,0  q 25,25 50,0"/>
        #|
        #|    <path d="M 290,120 C 310,140 320,100, 340,120 M 390,120 C 410,140 420,100 440,120"/>
        #|
        #|    <path d="M 290,240 Q 315,265 340,240  M 390,240  Q 415,265 440,240"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 50,120  c 20,20 30,-20 50,0 m 50,0 c 20,20 30,-20 50,0"/>
        #|
        #|    <path d="m 50,240  q 25,25 50,0  m 50,0  q 25,25 50,0"/>
        #|
        #|    <path d="M 290,120 C 310,140 320,100, 340,120 M 390,120 C 410,140 420,100 440,120"/>
        #|
        #|    <path d="M 290,240 Q 315,265 340,240  M 390,240  Q 415,265 440,240"/>
        #|
        #|    <g id="cubic">
        #|      <path d="m  50,120 20,20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,120 20,20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,120 20,20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,120 20,20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#cubic"  transform="translate(240,  0)"/>
        #|
        #|    <g id="quadratic">
        #|      <path d="m  50,240 20, 20"  style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,240 20,-20"  style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,240 20, 20"  style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,240 20,-20"  style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#quadratic"  transform="translate(240,  0)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      7,
      14,
    ),
    case(
      "painting/reftests/marker-path-013.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-013-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2;marker-start:url(#Start);marker-mid:url(#Mid);marker-end:url(#End)">
        #|    <path d="m  50,120  a 30,20 90 0 0 50,0     m  50,0    a 30,20 90 0 0 50,0"/>
        #|
        #|    <path d="m  50,240  a 30,20 90 0 1 50,0     m  50,0    a 30,20 90 0 1 50,0"/>
        #|
        #|    <path d="M 290,120  A 30,20 90 0 0 340,120  M 390,120  A 30,20 90 0 0 440,120"/>
        #|
        #|    <path d="M 290,240  A 30,20 90 0 1 340,240  M 390,240  A 30,20 90 0 1 440,240"/>
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Sub-Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m  50,120  a 30,20 90 0 0 50,0     m  50,0    a 30,20 90 0 0 50,0"/>
        #|
        #|    <path d="m  50,240  a 30,20 90 0 1 50,0     m  50,0    a 30,20 90 0 1 50,0"/>
        #|
        #|    <path d="M 290,120  A 30,20 90 0 0 340,120  M 390,120  A 30,20 90 0 0 440,120"/>
        #|
        #|    <path d="M 290,240  A 30,20 90 0 1 340,240  M 390,240  A 30,20 90 0 1 440,240"/>
        #|
        #|    <g id="down">
        #|      <path d="m  50,120 0, 20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,120 0,-20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,120 0, 20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,120 0,-20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#down"  transform="translate(240,  0)"/>
        #|
        #|    <g id="up">
        #|      <path d="m  50,240 0,-20"   style="stroke:none;marker-start:url(#Start)"/>
        #|      <path d="m 100,240 0, 20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 150,240 0,-20"   style="stroke:none;marker-start:url(#Mid)"/>
        #|      <path d="m 200,240 0, 20"   style="stroke:none;marker-start:url(#End)"/>
        #|    </g>
        #|    <use xlink:href="#up"  transform="translate(240,  0)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-path-021.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-021-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 120,100 -40,40 40,40 40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m 240,100 -40,40 40,40 40,-40 z" style="marker-mid:url(#Mid)"    />
        #|    <path d="m 360,100 -40,40 40,40 40,-40 z" style="marker-end:url(#End)"    />
        #|
        #|    <path d="m  60,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m 200,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" style="marker-mid:url(#Mid)"    />
        #|    <path d="m 340,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" style="marker-end:url(#End)"    />
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Linear).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 120,100 -40,40 40,40 40,-40 z" />
        #|    <path d="m 240,100 -40,40 40,40 40,-40 z" />
        #|    <path d="m 360,100 -40,40 40,40 40,-40 z" />
        #|
        #|    <path d="m  60,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" />
        #|    <path d="m 200,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" />
        #|    <path d="m 340,200 -40,40 40,40 40,-40 z  m 60,60 -40,40 40,40 40,-40 z" />
        #|
        #|    <!-- Arrows -->
        #|    <path d="m 120,100 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|    <path d="m 200,140   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,180  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 280,140   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 360,100 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|    <path d="m  60,200 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|
        #|    <path d="m 160,240   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,280  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,240   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,200 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 220,300   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,340  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 300,300   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,260 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 400,260 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-path-022.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-022-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 120,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m 240,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-mid:url(#Mid)"/>
        #|    <path d="m 360,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-end:url(#End)"/>
        #|
        #|    <path d="m 60,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m 200,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-mid:url(#Mid)"/>
        #|    <path d="m 340,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z" style="marker-end:url(#End)"/>
        #|</g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Bezier).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m 120,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|    <path d="m 240,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|    <path d="m 360,100 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|
        #|    <path d="m 60,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|    <path d="m 200,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|    <path d="m 340,200 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z m 60,60 c -40,0 -40,0 -40,40 c 0,40 0,40 40,40 c 40,0 40,0 40,-40 c 0,-40 0,-40 -40,-40 z"/>
        #|
        #|    <!-- Arrows -->
        #|    <path d="m 120,100 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|    <path d="m 200,140   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,180  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 280,140   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 360,100 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|    <path d="m  60,200 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|
        #|    <path d="m 160,240   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,280  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,240   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,200 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 220,300   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,340  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 300,300   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,260 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 400,260 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/marker-path-023.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#Markers"/>
        #|    <html:link rel="match"  href="marker-path-023-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-content" style="fill:none;stroke:black;stroke-width:2">
        #|
        #|    <path d="m  120,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m  240,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-mid:url(#Mid)"/>
        #|    <path d="m  360,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-end:url(#End)"/>
        #|
        #|    <path d="m   60,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-start:url(#Start)"/>
        #|    <path d="m  200,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-mid:url(#Mid)"/>
        #|    <path d="m  340,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z" style="marker-end:url(#End)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Markers on Closed Sub-Path (Arc).</title>
        #|    <html:link rel="author"
        #|          title="Tavmjong Bah"
        #|          href="http://tavmjong.free.fr"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <marker id="Start"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="green">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="Mid"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="orange">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|    <marker id="End"
        #|            viewBox="0 0 10 10" refX="0" refY="5"
        #|            markerUnits="strokeWidth"
        #|            markerWidth="12"
        #|            markerHeight="9"
        #|            orient="auto"
        #|            fill="blue">
        #|      <path d="M 0 0 L 10 5 L 0 10 z"/>
        #|    </marker>
        #|  </defs>
        #|
        #|  <g id="test-body-reference" style="fill:none;stroke:black;stroke-width:2">
        #|    <path d="m  120,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|    <path d="m  240,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|    <path d="m  360,100  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|
        #|    <path d="m   60,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|    <path d="m  200,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|    <path d="m  340,200  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z m 60,60  a 40,40 0 0 0 -40,40  a  40,40 0 0 0 40,40 a 40,40 0 0 0 40,-40 a 40,40 0 0 0 -40,-40 z"/>
        #|
        #|    <!-- Arrows -->
        #|    <path d="m 120,100 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|    <path d="m 200,140   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,180  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 280,140   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 360,100 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|    <path d="m  60,200 -40,  0"   style="stroke:none;marker-start:url(#Start)"/>
        #|
        #|    <path d="m 160,240   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,280  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 240,240   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 200,200 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 220,300   0, 40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,340  40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 300,300   0,-40"   style="stroke:none;marker-start:url(#Mid)"/>
        #|    <path d="m 260,260 -40,  0"   style="stroke:none;marker-start:url(#Mid)"/>
        #|
        #|    <path d="m 400,260 -40,  0"   style="stroke:none;marker-start:url(#End)"/>
        #|
        #|  </g>
        #|
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/markers-orient-002.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>orient='auto' with 180 degree turns</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#RenderingMarkers"/>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|  <marker id="m" markerWidth="100" markerHeight="50" markerUnits="userSpaceOnUse"
        #|          orient="auto" refX="50" refY="50">
        #|    <path d="M50,-5L105,50h-110z" fill="green"/>
        #|  </marker>
        #|  <g marker-start="url(#m)">
        #|    <path d="M50,0v50z"/>
        #|    <path d="M100,50h-50z"/>
        #|    <path d="M50,100v-50z"/>
        #|    <path d="M0,50h50z"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "painting/reftests/mask-print.svg",
      (
        #|<svg width="200" height="200" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|xmlns:html="http://www.w3.org/1999/xhtml">
        #|<html:meta name="fuzzy" content="0-1;0-17280" />
        #|<html:link rel="match"  href="mask-print-ref.svg" />
        #|<defs>
        #|<mask id="Mask">
        #|<rect x="0" y="0" width="100" height="200" fill="white" />
        #|</mask>
        #|</defs>
        #|
        #|<rect x="0" y="0" width="200" height="200" fill="green" />
        #|<rect x="0" y="0" width="200" height="200" fill="red" mask="url(#Mask)" />
        #|<rect x="90" y="0" width="20" height="200" fill="black" />
        #|<rect x="0" y="0" width="200" height="4" fill="black" />
        #|</svg>
        #|
      ),
      (
        #|<svg width="200" height="200" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|<rect x="0" y="0" width="200" height="200" fill="green" />
        #|<rect x="0" y="0" width="100" height="200" fill="red"/>
        #|<rect x="90" y="0" width="20" height="200" fill="black" />
        #|<rect x="0" y="0" width="200" height="4" fill="black" />
        #|</svg>
        #|
      ),
      200,
      200,
      1,
      17280,
    ),
    case(
      "painting/reftests/paint-context-003.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' vis-a-vis 'currentcolor'</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|    <html:link rel="match" href="paint-context-003-ref.svg"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <g id="g" color="green">
        #|      <rect width="100" height="100" fill="context-fill" stroke="context-stroke"/>
        #|    </g>
        #|  </defs>
        #|
        #|  <g id="test-body-content" color="red" style="stroke-width:15px">
        #|    <use x="25" y="25" href="#g" stroke="none" fill="currentcolor"/>
        #|    <use x="150" y="25" href="#g" stroke="currentcolor" fill="none"/>
        #|  </g>
        #|</svg>
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 480 360"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' vis-a-vis 'currentcolor'</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|  </g>
        #|
        #|  <g style="stroke-width:15px">
        #|    <rect x="25" y="25" width="100" height="100" fill="green" stroke="none"/>
        #|    <rect x="150" y="25" width="100" height="100" fill="none" stroke="green"/>
        #|  </g>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-context-004.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 120 90"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' with paint server</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|    <html:link rel="match"  href="paint-context-004-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <pattern id="grid" x="0" y="0" width="0.125" height="0.125" stroke="blue" stroke-width="0.03125" patternContentUnits="objectBoundingBox">
        #|      <path d="M 0,0.0625 h 0.125"/>
        #|      <path d="M 0.0625,0 v 0.125"/>
        #|    </pattern>
        #|
        #|    <g id="rects">
        #|      <rect x="0" y="0" width="32" height="64" fill="context-fill"/>
        #|      <rect x="32" y="6" width="32" height="58" fill="context-fill"/>
        #|    </g>
        #|  </defs>
        #|
        #|  <g id="test-body-content">
        #|    <use x="18" y="18" fill="url(#grid)" xlink:href="#rects"/>
        #|  </g>
        #|</svg>
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 120 90"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' with paint server</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <pattern id="grid-ref" x="0" y="0" width="8" height="8" stroke="blue" stroke-width="2" patternUnits="userSpaceOnUse">
        #|      <path d="M 0,4 h 8"/>
        #|      <path d="M 4,0 v 8"/>
        #|    </pattern>
        #|
        #|    <g id="rects-ref" fill="url(#grid-ref)">
        #|      <rect x="0" y="0" width="32" height="64"/>
        #|      <rect x="32" y="6" width="32" height="58"/>
        #|    </g>
        #|  </defs>
        #|
        #|  <g id="ref-content">
        #|    <use x="18" y="18" xlink:href="#rects-ref"/>
        #|  </g>
        #|</svg>
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-context-006.svg",
      (
        #|<svg id="svg-root" viewBox="0 0 800 600"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' for markers with gradient</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|    <html:link rel="match"  href="paint-context-006-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <linearGradient id="lg">
        #|      <stop offset="0" stop-color="red"/>
        #|      <stop offset="1" stop-color="blue"/>
        #|    </linearGradient>
        #|
        #|    <marker id="inner-marker" refX="50" refY="20" markerWidth="100" markerHeight="50">
        #|      <rect width="100" height="50" fill="context-fill"/>
        #|    </marker>
        #|
        #|    <marker id="marker" refX="50" refY="340" markerWidth="100" markerHeight="400" orient="0.25turn">
        #|      <g fill="context-fill">
        #|        <rect y="40" width="100" height="360"/>
        #|        <text x="30" y="200" style="font-size:96px" stroke="black" rotate="-45">A</text>
        #|        <path d="M 50 40 v -20" marker-end="url(#inner-marker)"/>
        #|      </g>
        #|    </marker>
        #|  </defs>
        #|
        #|  <path id="test-body-content" fill="url(#lg)"
        #|        d="M 150 125 h 540 v 400 h -540 Z"
        #|        marker-start="url(#marker)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root" viewBox="0 0 800 600"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' for markers with gradient</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <linearGradient id="lg" x1="10%">
        #|        <stop offset="0" stop-color="red"/>
        #|        <stop offset="1" stop-color="blue"/>
        #|    </linearGradient>
        #|  </defs>
        #|
        #|  <path id="test-reference" fill="url(#lg)"
        #|        d="M 90 75 h 400 v 50 h 200 v 400 h -540 v -350 h -60 Z"/>
        #|  <text x="290" y="105" style="font-size:96px" stroke="black" fill="none" rotate="45">A</text>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-context-007.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 400 300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' in 'use' with transform</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|    <html:link rel="match"  href="paint-context-007-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <linearGradient id="lg">
        #|      <stop offset="0" stop-color="red"/>
        #|      <stop offset="1" stop-color="blue"/>
        #|    </linearGradient>
        #|
        #|    <g id="shapes">
        #|      <rect x="50" y="90" width="240" height="120" fill="context-fill"/>
        #|      <path d="M 170 -30 l -120 240 l 240 0 Z" fill="context-fill"
        #|            transform-origin="170 150" transform="rotate(90)"/>
        #|    </g>
        #|  </defs>
        #|
        #|  <g id="test-body-content">
        #|    <use x="0" y="0" fill="url(#lg)" xlink:href="#shapes"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 400 300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: 'context-fill' and 'context-stroke' in 'use' with transform</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <linearGradient id="lg1" x2="125%">
        #|      <stop offset="0" stop-color="red"/>
        #|      <stop offset="1" stop-color="blue"/>
        #|    </linearGradient>
        #|
        #|    <linearGradient id="lg2" x1="-25%">
        #|      <stop offset="0" stop-color="red"/>
        #|      <stop offset="1" stop-color="blue"/>
        #|    </linearGradient>
        #|  </defs>
        #|
        #|  <g id="test-reference">
        #|    <rect x="50" y="90" width="240" height="120" fill="url(#lg1)"/>
        #|    <path d="M 110 30 l 240 120 l -240 120 Z" fill="url(#lg2)" />
        #|  </g>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-context-008.svg",
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 400 300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: paint server transform for 'context-fill' based on nearest 'use' ancestor</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint"/>
        #|    <html:link rel="match"  href="paint-context-008-ref.svg" />
        #|  </g>
        #|
        #|  <defs>
        #|    <pattern id="grid" x="0" y="0" width="0.125" height="0.25" stroke="blue" stroke-width="0.03125" patternContentUnits="objectBoundingBox">
        #|      <path fill="none" d="M 0.0625 0 l 0.0625 0.125 l -0.0625 0.125 l -0.0625 -0.125 Z"/>
        #|    </pattern>
        #|
        #|    <g id="shapes">
        #|      <rect x="50" y="90" width="256" height="128" fill="context-fill"/>
        #|    </g>
        #|
        #|    <g id="intermediate">
        #|      <use x="19" y="23" fill="url(#grid)" xlink:href="#shapes"/>
        #|    </g>
        #|  </defs>
        #|
        #|  <g id="test-body-content">
        #|    <use xlink:href="#intermediate"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg id="svg-root"
        #|  width="100%" height="100%" viewBox="0 0 400 300"
        #|  xmlns="http://www.w3.org/2000/svg"
        #|  xmlns:xlink="http://www.w3.org/1999/xlink"
        #|  xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Paint: paint server transform for 'context-fill' based on nearest 'use' ancestor</title>
        #|    <html:link rel="author"
        #|          title="Stefan Zager"
        #|          href="mailto:szager@chromium.org"/>
        #|  </g>
        #|
        #|  <defs>
        #|    <pattern id="grid" x="0" y="0" width="0.125" height="0.25" stroke="blue" stroke-width="0.03125" patternContentUnits="objectBoundingBox">
        #|      <path fill="none" d="M 0.0625 0 l 0.0625 0.125 l -0.0625 0.125 l -0.0625 -0.125 Z"/>
        #|    </pattern>
        #|  </defs>
        #|
        #|  <g id="test-reference">
        #|    <rect x="69" y="113" width="256" height="128" fill="url(#grid)"/>
        #|  </g>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-order-002.svg",
      (
        #|<svg viewBox="-10 -10 280 220" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="paint-order-002-ref.svg"/>
        #|  <defs>
        #|    <marker id="m" refX="5" refY="5" viewBox="0 0 10 10" overflow="visible">
        #|      <circle cx="5" cy="5" r="3" fill="black" stroke="black" fill-opacity="0.5"/>
        #|    </marker>
        #|    <svg id="poly" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke="lime" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|    </svg>
        #|  </defs>
        #|
        #|  <use xlink:href="#poly" width="50" height="50"/>
        #|  <use xlink:href="#poly" style="paint-order: normal" width="50" height="50" x="50"/>
        #|
        #|  <g transform="translate(0,50)">
        #|    <use xlink:href="#poly" style="paint-order: fill" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: fill stroke" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: fill stroke markers" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: fill markers" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: fill markers stroke" width="50" height="50" x="200" />
        #|  </g>
        #|
        #|  <g transform="translate(0,100)">
        #|    <use xlink:href="#poly" style="paint-order: stroke" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke fill" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke fill markers" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke markers" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke markers fill" width="50" height="50" x="200"/>
        #|  </g>
        #|
        #|  <g transform="translate(0,150)">
        #|    <use xlink:href="#poly" style="paint-order: markers" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: markers stroke" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: markers stroke fill" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: markers fill" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: markers fill stroke" width="50" height="50" x="200"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg viewBox="-10 -10 280 220" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <defs>
        #|    <marker id="m" refX="5" refY="5" viewBox="0 0 10 10" overflow="visible">
        #|      <circle cx="5" cy="5" r="3" fill="black" stroke="black" fill-opacity="0.5"/>
        #|    </marker>
        #|    <svg id="poly" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke="lime" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|    </svg>
        #|    <svg id="poly-f-m-s" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke="lime" stroke-width="50" stroke-opacity="0.5"/>
        #|    </svg>
        #|    <svg id="poly-m-f-s" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke-width="50" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke="lime" stroke-width="50" stroke-opacity="0.5"/>
        #|    </svg>
        #|    <svg id="poly-s-m-f" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke="lime" stroke-width="50" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke-width="50" stroke-opacity="0.5"/>
        #|    </svg>
        #|    <svg id="poly-s-f-m" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke="lime" stroke-width="50" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke-width="50" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|    </svg>
        #|    <svg id="poly-m-s-f" viewBox="-10 -10 420 420">
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke-width="50" style="marker: url(#m)" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="none" stroke="lime" stroke-width="50" stroke-opacity="0.5"/>
        #|      <polygon points="50 50 50 350 350 350 250 200" fill="blue" stroke-width="50" stroke-opacity="0.5"/>
        #|    </svg>
        #|  </defs>
        #|
        #|  <use xlink:href="#poly" width="50" height="50"/>
        #|  <use xlink:href="#poly" width="50" height="50" x="50"/>
        #|
        #|  <g transform="translate(0,50)">
        #|    <use xlink:href="#poly" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-f-m-s" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-f-m-s" width="50" height="50" x="200" />
        #|  </g>
        #|
        #|  <g transform="translate(0,100)">
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-s-m-f" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-s-m-f" width="50" height="50" x="200"/>
        #|  </g>
        #|
        #|  <g transform="translate(0,150)">
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly-m-s-f" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly-m-s-f" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="200"/>
        #|  </g>
        #|</svg>
        #|
      ),
      280,
      220,
      -1,
      -1,
    ),
    case(
      "painting/reftests/paint-order-003.svg",
      (
        #|<svg viewBox="-10 -10 280 220" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="paint-order-003-ref.svg"/>
        #|  <defs>
        #|    <marker id="m" refX="5" refY="5" viewBox="0 0 10 10" overflow="visible">
        #|      <circle cx="5" cy="5" r="3" fill="black" stroke="black" fill-opacity="0.5"/>
        #|    </marker>
        #|    <svg id="poly" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke="lime" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|    </svg>
        #|  </defs>
        #|
        #|  <use xlink:href="#poly" width="50" height="50"/>
        #|  <use xlink:href="#poly" style="paint-order: normal" width="50" height="50" x="50"/>
        #|
        #|  <g transform="translate(0,50)">
        #|    <use xlink:href="#poly" style="paint-order: fill" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: fill stroke" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: fill stroke markers" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: fill markers" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: fill markers stroke" width="50" height="50" x="200" />
        #|  </g>
        #|
        #|  <g transform="translate(0,100)">
        #|    <use xlink:href="#poly" style="paint-order: stroke" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke fill" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke fill markers" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke markers" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: stroke markers fill" width="50" height="50" x="200"/>
        #|  </g>
        #|
        #|  <g transform="translate(0,150)">
        #|    <use xlink:href="#poly" style="paint-order: markers" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" style="paint-order: markers stroke" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" style="paint-order: markers stroke fill" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly" style="paint-order: markers fill" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly" style="paint-order: markers fill stroke" width="50" height="50" x="200"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg viewBox="-10 -10 280 220" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <defs>
        #|    <marker id="m" refX="5" refY="5" viewBox="0 0 10 10" overflow="visible">
        #|      <circle cx="5" cy="5" r="3" fill="black" stroke="black" fill-opacity="0.5"/>
        #|    </marker>
        #|    <svg id="poly" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke="lime" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|    </svg>
        #|    <svg id="poly-f-m-s" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke="lime" stroke-width="10" stroke-opacity="0.5">test</text>
        #|    </svg>
        #|    <svg id="poly-m-f-s" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke-width="10" stroke-opacity="0.5">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke="lime" stroke-width="10" stroke-opacity="0.5">test</text>
        #|    </svg>
        #|    <svg id="poly-s-m-f" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke="lime" stroke-width="10" stroke-opacity="0.5">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke-width="10" stroke-opacity="0.5">test</text>
        #|    </svg>
        #|    <svg id="poly-s-f-m" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke="lime" stroke-width="10" stroke-opacity="0.5">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke-width="10" stroke-opacity="0.5">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|    </svg>
        #|    <svg id="poly-m-s-f" viewBox="-10 -10 420 420">
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke-width="10" stroke-opacity="0.5" style="marker: url(#m)">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="none" stroke="lime" stroke-width="10" stroke-opacity="0.5">test</text>
        #|      <text y="300" font-family="sans-serif" font-size="200" fill="blue" stroke-width="10" stroke-opacity="0.5">test</text>
        #|    </svg>
        #|  </defs>
        #|
        #|  <use xlink:href="#poly" width="50" height="50"/>
        #|  <use xlink:href="#poly" width="50" height="50" x="50"/>
        #|
        #|  <g transform="translate(0,50)">
        #|    <use xlink:href="#poly" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-f-m-s" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-f-m-s" width="50" height="50" x="200" />
        #|  </g>
        #|
        #|  <g transform="translate(0,100)">
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly-s-f-m" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-s-m-f" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-s-m-f" width="50" height="50" x="200"/>
        #|  </g>
        #|
        #|  <g transform="translate(0,150)">
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="0"/>
        #|    <use xlink:href="#poly-m-s-f" width="50" height="50" x="50"/>
        #|    <use xlink:href="#poly-m-s-f" width="50" height="50" x="100"/>
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="150"/>
        #|    <use xlink:href="#poly-m-f-s" width="50" height="50" x="200"/>
        #|  </g>
        #|</svg>
        #|
      ),
      280,
      220,
      -1,
      -1,
    ),
    case(
      "painting/reftests/pattern-external-reference.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|<defs>
        #|<pattern id="greenPattern" viewBox="0 0 1 1" width="1" height="1">
        #|    <rect width="1" height="1" fill="green"/>
        #|  </pattern>
        #|  <linearGradient id="greenGradient">
        #|    <stop stop-color="green"/>
        #|  </linearGradient>
        #|  <linearGradient id="redGradient">
        #|    <stop stop-color="red"/>
        #|  </linearGradient>
        #|  <marker id="greenMarkerOrient0" orient="0"
        #|          markerWidth="10" markerHeight="10" refX="5" refY="5">
        #|    <rect width="10" height="10" fill="green"/>
        #|  </marker>
        #|</defs>
        #|  <title>External file reference for pattern</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#SpecifyingFillPaint"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/painting.html#SpecifyingStrokePaint"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/pservers.html#Patterns"/>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/linking.html#URLReference"/>
        #|  <h:link rel="match" href="../../pservers/reftests/reference/green-100x100.svg"/>
        #|
        #|  <rect width="100" height="100" fill="url(#greenPattern) red"/>
        #|  <rect x="25" y="25" width="50" height="50" fill="none" stroke-width="20"
        #|        stroke="url(#greenPattern) orange"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-currentcolor-1.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <linearGradient id="lg">
        #|    <stop stop-color="#008000"/>
        #|  </linearGradient>
        #|  <!-- Test that 'fill' on the 'rect' uses the gradient 'lg'. -->
        #|  <g color="#ff0000" fill="#ff0000">
        #|    <rect width="100" height="100" fill="url(#lg) currentColor"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-currentcolor-2.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <!-- Test that 'fill' on the 'rect' falls back to currentColor (green). -->
        #|  <g color="#008000" fill="#ff0000">
        #|    <rect width="100" height="100" fill="url(#notfound) currentColor"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-invalid-uri.svg",
      (
        #|<svg fill="red" xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <rect width="100" height="100" fill="url(#nonexisting)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-none-1.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <linearGradient id="lg">
        #|    <stop stop-color="#008000"/>
        #|  </linearGradient>
        #|  <!-- Test that 'fill' on the 'rect' uses the gradient 'lg'. -->
        #|  <rect width="100" height="100" fill="url(#lg) none"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-none-2.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <rect width="100" height="100" fill="#008000"/>
        #|  <!-- Test that 'fill' on the 'rect' falls back to 'none'. -->
        #|  <g fill="#ff0000">
        #|    <rect width="100" height="100" fill="url(#notfound) none"/>
        #|  </g>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/fill-fallback-none-3.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" fill="red">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <linearGradient id="working">
        #|    <stop stop-color="green"/>
        #|  </linearGradient>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <rect width="100" height="100" fill="url(#broken) none" stroke="url(#working)" stroke-width="0"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/gradient-inheritance-not-in-rendertree-01.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http:/www.w3.org/1999/xhtml">
        #|  <title>&#x3c;linearGradient&#x3e; (without content) inheriting from a &#x3c;linearGradient&#x3e; in an invalid context</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/pservers.html#StopNotes"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <linearGradient id="linearGradient1" xlink:href="#linearGradient0"/>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <rect width="100" height="100" fill="url(#linearGradient1) yellow"/>
        #|  <text>
        #|    <linearGradient id="linearGradient0">
        #|      <stop stop-color="orange"/>
        #|    </linearGradient>
        #|  </text>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/gradient-inheritance-not-in-rendertree-02.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http:/www.w3.org/1999/xhtml">
        #|  <title>&#x3c;linearGradient&#x3e; (with content) inheriting from a &#x3c;linearGradient&#x3e; in an invalid context</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/pservers.html#StopNotes"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <linearGradient id="linearGradient1" xlink:href="#linearGradient0">
        #|    <stop stop-color="green"/>
        #|  </linearGradient>
        #|  <rect width="100" height="100" fill="url(#linearGradient1) yellow"/>
        #|  <text>
        #|    <linearGradient id="linearGradient0">
        #|      <stop stop-color="orange"/>
        #|    </linearGradient>
        #|  </text>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/gradient-transform-01.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Gradients with non-invertible gradientTransforms, linearGradient</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/single-page.html#pservers-LinearGradientElementGradientTransformAttribute"/>
        #|  <h:link rel="help" href="https://drafts.csswg.org/css-transforms/#transform-function-lists"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|
        #|  <linearGradient id="scale0" gradientTransform="scale(0)">
        #|    <stop offset="0" stop-color="yellow"/>
        #|    <stop offset="1" stop-color="red"/>
        #|  </linearGradient>
        #|  <rect width="50" height="100" fill="url(#scale0) green"/>
        #|
        #|  <linearGradient id="matrix0" gradientTransform="matrix(0, 0, 0, 0, 0, 0)">
        #|    <stop offset="0" stop-color="yellow"/>
        #|    <stop offset="1" stop-color="red"/>
        #|  </linearGradient>
        #|  <rect x="50" width="50" height="100" fill="url(#matrix0) green"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/gradient-transform-02.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Gradients with non-invertible gradientTransforms, radialGradient</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/single-page.html#pservers-RadialGradientElementGradientTransformAttribute"/>
        #|  <h:link rel="help" href="https://drafts.csswg.org/css-transforms/#transform-function-lists"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|
        #|  <radialGradient id="scale0" gradientTransform="scale(0)">
        #|    <stop offset="0" stop-color="yellow"/>
        #|    <stop offset="1" stop-color="red"/>
        #|  </radialGradient>
        #|  <rect width="50" height="100" fill="url(#scale0) green"/>
        #|
        #|  <radialGradient id="matrix0" gradientTransform="matrix(0, 0, 0, 0, 0, 0)">
        #|    <stop offset="0" stop-color="yellow"/>
        #|    <stop offset="1" stop-color="red"/>
        #|  </radialGradient>
        #|  <rect x="50" width="50" height="100" fill="url(#matrix0) green"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-inheritance-not-in-rendertree-01.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http:/www.w3.org/1999/xhtml">
        #|  <title>&#x3c;pattern&#x3e; (without content) inheriting from a &#x3c;pattern&#x3e; in an invalid context</title>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <pattern id="pattern1" xlink:href="#pattern0" width="1" height="1"/>
        #|  <rect width="100" height="100" fill="url(#pattern1) green"/>
        #|  <text>
        #|    <pattern id="pattern0">
        #|      <rect width="100" height="100" fill="orange"/>
        #|    </pattern>
        #|  </text>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-inheritance-not-in-rendertree-02.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg"
        #|     xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http:/www.w3.org/1999/xhtml">
        #|  <title>&#x3c;pattern&#x3e; (with content) inheriting from a &#x3c;pattern&#x3e; in an invalid context</title>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <pattern id="pattern1" xlink:href="#pattern0" width="1" height="1">
        #|    <rect width="100" height="100" fill="green"/>
        #|  </pattern>
        #|  <rect width="100" height="100" fill="url(#pattern1) yellow"/>
        #|  <text>
        #|    <pattern id="pattern0">
        #|      <rect width="100" height="100" fill="orange"/>
        #|    </pattern>
        #|  </text>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-opacity-01.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Pattern: fill-opacity</title>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/pservers.html#Patterns"/>
        #|    <html:link rel="match" href="reference/pattern-opacity-01-ref.svg"/>
        #|  </g>
        #|  <defs>
        #|    <pattern id="pattern" width='1' height='1' patternContentUnits="objectBoundingBox">>
        #|      <rect fill="lime" width="1" height="1"/>
        #|    </pattern>
        #|  </defs>
        #|  <rect width="100%" height="100%" fill-opacity="0.5" fill="url(#pattern)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100%" height="100%" fill-opacity="0.5" fill="lime"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-text-01.svg",
      (
        #|<svg height="100px" width="100px" viewBox="0 0 1000 300" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <metadata>
        #|    <h:title>pattern on text elements</h:title>
        #|    <h:link rel="help" href="https://www.w3.org/TR/SVG2/pservers.html#Patterns"/>
        #|    <h:link rel="match" href="reference/green-100x100.svg"/>
        #|    <h:link rel="stylesheet" type="text/css" href="/fonts/ahem.css" />
        #|  </metadata>
        #|  <defs>
        #|    <pattern id="green" width="10%" height="10%" patternUnits="userSpaceOnUse">
        #|      <rect width="8%" height="8%" fill="green"/>
        #|    </pattern>
        #|    <pattern id="red" width="10%" height="10%" patternUnits="userSpaceOnUse">
        #|      <rect x="0.5%" y="0.5%" width="7%" height="7%" fill="red"/>
        #|    </pattern>
        #|  </defs>
        #|  <rect fill="green" width="1000" height="300"/>
        #|
        #|  <!-- the text should be covered by the rect that follows -->
        #|  <text fill="url(#red)" font-family="Ahem" font-size="100px" x="50" y="150">XXXXXXXX</text>
        #|  <rect fill="url(#green)" width="1000" height="300"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-transform-01.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2 2" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Pattern: with patternTransform</title>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/pservers.html#Patterns"/>
        #|    <html:link rel="match" href="reference/pattern-transform-01-ref.svg"/>
        #|  </g>
        #|    <defs>
        #|      <pattern id="pattern" patternTransform="translate(.5 .5)" patternUnits="userSpaceOnUse" width="2" height="2">
        #|        <path d="M0 0h1v1H0zM1 1h1v1H1z" />
        #|      </pattern>
        #|    </defs>
        #|    <rect width="2" height="2" fill="url(#pattern)" />
        #|</svg>
        #|
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0.5 0.5 2 2" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <defs>
        #|    <pattern id="pattern" patternUnits="userSpaceOnUse" width="2" height="2">
        #|      <path d="M0 0h1v1H0zM1 1h1v1H1z" />
        #|    </pattern>
        #|  </defs>
        #|  <rect x="0.5" y="0.5" width="2" height="2" fill="url(#pattern)" />
        #|</svg>
        #|
      ),
      2,
      2,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-transform-02.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Patterns with non-invertible patternTransforms</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/single-page.html#pservers-PatternElementPatternTransformAttribute"/>
        #|  <h:link rel="help" href="https://drafts.csswg.org/css-transforms/#transform-function-lists"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|
        #|  <pattern id="scale0" width="50" height="100"
        #|           patternTransform="scale(0)">
        #|    <rect width="50" height="100" fill="red"/>
        #|  </pattern>
        #|  <rect width="50" height="100" fill="url(#scale0) green"/>
        #|
        #|  <pattern id="matrix0" width="50" height="100"
        #|           patternTransform="matrix(0, 0, 0, 0, 0, 0)">
        #|    <rect width="50" height="100" fill="red"/>
        #|  </pattern>
        #|  <rect x="50" width="50" height="100" fill="url(#matrix0) green"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/pattern-viewbox-01.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5669 5669" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <g id="testmeta">
        #|    <title>Pattern: viewBox with x offset</title>
        #|    <html:link rel="help"
        #|          href="https://www.w3.org/TR/SVG2/pservers.html#Patterns"/>
        #|    <html:link rel="match" href="reference/pattern-viewbox-01-ref.svg"/>
        #|  </g>
        #|  <pattern width="2258.997" height="1289.823" patternUnits="userSpaceOnUse" id="pattern"
        #|           viewBox="752.999 0 2258.997 1289.823" patternTransform="scale(0.5)">
        #|    <g transform="translate(0,1934.735)" fill="none" stroke="black" stroke-width="10">
        #|      <rect x="752.999" y="-1934.735" width="2258.997" height="1289.823"/>
        #|      <circle cx="1882.4975" cy="-1289.8235" r="644.9115"/>
        #|    </g>
        #|  </pattern>
        #|  <rect width="100%" height="100%"  fill="url(#pattern)"/>
        #|</svg>
        #|
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5669 5669">
        #|  <pattern width="2258.997" height="1289.823" patternUnits="userSpaceOnUse" id="pattern"
        #|           viewBox="0 0 2258.997 1289.823" patternTransform="scale(0.5)">
        #|    <g transform="translate(-752.999, 1934.735)" fill="none" stroke="black" stroke-width="10">
        #|      <rect x="752.999" y="-1934.735" width="2258.997" height="1289.823"/>
        #|      <circle cx="1882.4975" cy="-1289.8235" r="644.9115"/>
        #|    </g>
        #|  </pattern>
        #|  <rect width="100%" height="100%"  fill="url(#pattern)"/>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/radialgradient-fully-overlapping.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Radial gradient with overlapping start and end circles</title>
        #|  <metadata>
        #|    <h:link rel="help" href="https://svgwg.org/svg2-draft/pservers.html#RadialGradientNotes"/>
        #|    <h:link rel="match" href="reference/green-100x100.svg"/>
        #|    <h:meta name="assert" content="If the start circle fully overlaps with the end circle, the gradient should be drawn."/>
        #|  </metadata>
        #|
        #|  <rect width="100" height="100" fill="red"/>
        #|
        #|  <radialGradient id="fully_overlapping" r="100" fr="100">
        #|    <stop stop-color="green"/>
        #|    <stop stop-color="green" offset="1"/>
        #|  </radialGradient>
        #|  <rect width="100" height="100" fill="url(#fully_overlapping) orange"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "pservers/reftests/stroke-fallback-invalid-uri.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" stroke="red" stroke-width="50">
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <rect x="25" y="25" width="50" height="50" fill="none" stroke="green"/>
        #|  <rect x="25" y="25" width="50" height="50" fill="none" stroke="url(#nonexisting)"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      50,
      50,
      -1,
      -1,
    ),
    case(
      "struct/reftests/gradient-in-symbol.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <title>&#x3c;symbol&#x3e; with a gradient inside</title>
        #|  <h:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SymbolElement"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <rect fill="url(#a)" width="100" height="100"/>
        #|  <symbol>
        #|    <linearGradient id="a">
        #|      <stop offset="5%" stop-color="green" />
        #|    </linearGradient>
        #|  </symbol>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/inner-svg-css-transform.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SVGElement"/>
        #|  <html:link rel="match" href="reference/inner-svg-transform-ref.svg"/>
        #|  <title>Test that transforms the inner svg element using css</title>
        #|  <svg width="50" height="50" style="transform: translate(100px, 50px) scale(2);">
        #|    <rect width="50" height="50" fill="green"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <g transform="translate(100,50) scale(2)">
        #|    <svg width="50" height="50">
        #|      <rect width="50" height="50" fill="green"/>
        #|    </svg>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/inner-svg-rotate-transform.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SVGElement"/>
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/coords.html#TransformProperty"/>
        #|  <html:link rel="match" href="reference/inner-svg-rotate-transform-ref.svg"/>
        #|  <title>Test that rotates the inner svg element</title>
        #|  <svg width="50" height="50" transform="rotate(45)">
        #|    <rect width="50" height="50" fill="green"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <g transform="rotate(45)">
        #|    <svg width="50" height="50">
        #|      <rect width="50" height="50" fill="green"/>
        #|    </svg>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/inner-svg-transform-and-viewbox.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SVGElement"/>
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/coords.html#TransformProperty"/>
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/coords.html#ViewBoxAttribute"/>
        #|  <html:link rel="match" href="reference/inner-svg-transform-and-viewbox-ref.svg"/>
        #|  <title>Test that transforms the inner svg element with viewBox specified</title>
        #|  <svg width="50" height="50" transform="translate(100,50)" viewBox="0 0 40 40">
        #|    <rect width="50" height="50" fill="green"/>
        #|    <circle cx="25" cy="25" r="6"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <g transform="translate(100,50)">
        #|    <svg width="50" height="50" viewBox="0 0 40 40">
        #|      <rect width="50" height="50" fill="green"/>
        #|      <circle cx="25" cy="25" r="6"/>
        #|    </svg>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/inner-svg-transform.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SVGElement"/>
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/coords.html#TransformProperty"/>
        #|  <html:link rel="match" href="reference/inner-svg-transform-ref.svg"/>
        #|  <title>Test that transforms the inner svg element</title>
        #|  <svg width="50" height="50" transform="translate(100,50) scale(2)">
        #|    <rect width="50" height="50" fill="green"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <g transform="translate(100,50) scale(2)">
        #|    <svg width="50" height="50">
        #|      <rect width="50" height="50" fill="green"/>
        #|    </svg>
        #|  </g>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/outer-svg-transform.svg",
      (
        #|<svg width="400" height="400"  transform="translate(100,0)" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/struct.html#SVGElement"/>
        #|  <html:link rel="help" href="https://www.w3.org/TR/SVG2/coords.html#TransformProperty"/>
        #|  <html:link rel="match" href="reference/outer-svg-transform-ref.svg"/>
        #|  <title>Test that transforms the outer svg element"</title>
        #|  <svg width="50" height="50">
        #|    <rect width="50" height="50" fill="green"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg width="400" height="400" xmlns="http://www.w3.org/2000/svg">
        #|  <svg x="100" y="0" width="50" height="50">
        #|    <rect width="50" height="50" fill="green"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      400,
      400,
      -1,
      -1,
    ),
    case(
      "struct/reftests/requiredextensions-empty-string.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>requiredExtensions: present but empty attribute evaluates to false</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#RequiredExtensionsAttribute"/>
        #|  <h:link rel="match" href="../scripted/support/blank.svg"/>
        #|  <rect width="100" height="100" fill="red" requiredExtensions=""/>
        #|</svg>
        #|
      ),
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<svg xmlns="http://www.w3.org/2000/svg"></svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-a.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Testing that 'use' can target 'a' elements</title>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <a id="a">
        #|      <rect width="100" height="100" fill="green"/>
        #|    </a>
        #|  </defs>
        #|  <rect x="10" y="10" width="80" height="80" fill="red"/>
        #|
        #|  <use href="#a"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-data-url.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <title>&#x3c;use&#x3e; with a data: URL resource</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElementHrefAttribute"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <use href="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxyZWN0IGlkPSJyZWQtcmVjdCIgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiIGZpbGw9InJlZCIvPgo8L3N2Zz4=#red-rect"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-encoding.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <title>&#x3c;use&#x3e; with an encoded href</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElementHrefAttribute"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <rect id="a b" width="100" height="100" fill="green"/>
        #|  </defs>
        #|  <rect width="100" height="100" fill="red"/>
        #|  <use href="#a%20b"></use>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-no-tspan.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Testing that 'use' cannot make 'tspan' elements visible</title>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <text><tspan id="t" x="20" y="100" fill="red" font-size="36">Should not see this</tspan></text>
        #|  </defs>
        #|  <rect width="100" height="100" fill="green"/>
        #|
        #|  <use href="#t"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-svg-dimensions-override-001.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml" width="800" height="600">
        #|  <title>'width' and 'height' from &#x3c;use&#x3e; overrides values on referenced &#x3c;svg&#x3e;</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseLayout"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <svg id="s" width="10" height="10">
        #|      <rect width="100%" height="100%" fill="green"/>
        #|    </svg>
        #|  </defs>
        #|  <rect width="100" height="100" fill="red"/>
        #|  <svg width="1" height="1" overflow="visible">
        #|    <use xlink:href="#s" x="90" y="90"/>
        #|    <use xlink:href="#s" y="90" width="90"/>
        #|    <use xlink:href="#s" x="90" height="90"/>
        #|    <use xlink:href="#s" width="90" height="90"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-svg-dimensions-override-002.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml" width="800" height="600">
        #|  <title>'width' and 'height' from &#x3c;use&#x3e; overrides values on referenced &#x3c;svg&#x3e;</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseLayout"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <svg id="s">
        #|      <rect width="100%" height="100%" fill="green"/>
        #|    </svg>
        #|  </defs>
        #|  <rect width="100" height="100" fill="red"/>
        #|  <svg width="10" height="10" overflow="visible">
        #|    <use xlink:href="#s" x="90" y="90"/>
        #|    <use xlink:href="#s" y="90" width="90"/>
        #|    <use xlink:href="#s" x="90" height="90"/>
        #|    <use xlink:href="#s" width="90" height="90"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-svg-inline-css.svg",
      (
        #|<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height as inline CSS properties on use and referencing svg element</title>
        #|  <metadata>
        #|    <html:link rel="author" title="Virali Purbey" href="mailto:viralipurbey@microsoft.com"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElement"/>
        #|    <html:link rel="match" href="reference/green-100x100.svg"/>
        #|  </metadata>
        #|  <defs>
        #|    <svg id="svg" width="200" height="200">
        #|      <rect width="400" height="400" fill="green"/>
        #|    </svg>
        #|  </defs>
        #|  <use href="#svg" style="width:100px; height:100px"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-switch.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml">
        #|  <title>Testing that 'use' can target 'switch' elements</title>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <switch id="s">
        #|      <rect width="100" height="100" fill="green"/>
        #|    </switch>
        #|  </defs>
        #|  <rect x="10" y="10" width="80" height="80" fill="red"/>
        #|
        #|  <use href="#s"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-dimensions-override-001.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml" width="800" height="600">
        #|  <title>'width' and 'height' from &#x3c;use&#x3e; overrides values on referenced &#x3c;symbol&#x3e;</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseLayout"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <symbol id="s" width="10" height="10">
        #|      <rect width="100%" height="100%" fill="green"/>
        #|    </symbol>
        #|  </defs>
        #|  <rect width="100" height="100" fill="red"/>
        #|  <svg width="1" height="1" overflow="visible">
        #|    <use xlink:href="#s" x="90" y="90"/>
        #|    <use xlink:href="#s" y="90" width="90"/>
        #|    <use xlink:href="#s" x="90" height="90"/>
        #|    <use xlink:href="#s" width="90" height="90"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-dimensions-override-002.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
        #|     xmlns:h="http://www.w3.org/1999/xhtml" width="800" height="600">
        #|  <title>'width' and 'height' from &#x3c;use&#x3e; overrides values on referenced &#x3c;symbol&#x3e;</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseLayout"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <symbol id="s">
        #|      <rect width="100%" height="100%" fill="green"/>
        #|    </symbol>
        #|  </defs>
        #|  <rect width="100" height="100" fill="red"/>
        #|  <svg width="10" height="10" overflow="visible">
        #|    <use xlink:href="#s" x="90" y="90"/>
        #|    <use xlink:href="#s" y="90" width="90"/>
        #|    <use xlink:href="#s" x="90" height="90"/>
        #|    <use xlink:href="#s" width="90" height="90"/>
        #|  </svg>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      512,
      512,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-display-none.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:h="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink">
        #|  <title>&#x3c;use&#x3e; with a display="none" symbol</title>
        #|  <h:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElementHrefAttribute"/>
        #|  <h:link rel="match" href="reference/green-100x100.svg"/>
        #|  <defs>
        #|    <symbol id="a" display="none">
        #|      <rect width="100" height="100" fill="red"/>
        #|    </symbol>
        #|  </defs>
        #|  <rect width="100" height="100" fill="green"/>
        #|  <use href="#a"></use>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-inline-css-001.svg",
      (
        #|<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height as inline CSS properties on use and referencing symbol element</title>
        #|  <metadata>
        #|    <html:link rel="author" title="Virali Purbey" href="mailto:viralipurbey@microsoft.com"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#SymbolElement"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElement"/>
        #|    <html:link rel="match" href="reference/green-100x100.svg"/>
        #|  </metadata>
        #|  <defs>
        #|    <symbol id="sym" width="200" height="200">
        #|      <rect width="400" height="400" fill="green"/>
        #|    </symbol>
        #|  </defs>
        #|  <use href="#sym" style="width:100px; height:100px"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-inline-css-002.svg",
      (
        #|<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height as inline CSS properties on use and referencing symbol element doesn't have its width and height</title>
        #|  <metadata>
        #|    <html:link rel="author" title="Virali Purbey" href="mailto:viralipurbey@microsoft.com"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#SymbolElement"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElement"/>
        #|    <html:link rel="match" href="reference/green-100x100.svg"/>
        #|  </metadata>
        #|  <defs>
        #|    <symbol id="sym">
        #|      <rect width="400" height="400" fill="green"/>
        #|    </symbol>
        #|  </defs>
        #|  <use href="#sym" style="width:100px; height:100px"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "struct/reftests/use-symbol-inline-css-003.svg",
      (
        #|<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>No Width and Height defined on use and referencing symbol element has its width and height</title>
        #|  <metadata>
        #|    <html:link rel="author" title="Virali Purbey" href="mailto:viralipurbey@microsoft.com"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#SymbolElement"/>
        #|    <html:link rel="help" href="https://svgwg.org/svg2-draft/struct.html#UseElement"/>
        #|    <html:link rel="match" href="reference/green-100x100.svg"/>
        #|  </metadata>
        #|  <defs>
        #|    <symbol id="sym" width="100" height="100">
        #|      <rect width="400" height="400" fill="green"/>
        #|    </symbol>
        #|  </defs>
        #|  <use href="#sym"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      500,
      500,
      -1,
      -1,
    ),
    case(
      "styling/color-inherit-link-visited.svg",
      (
        #|<svg width="100" height="100" fill="green" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Privacy_and_the_:visited_selector"/>
        #|  <html:link rel="match" href="color-inherit-link-visited-ref.svg"/>
        #|  <html:meta name="assert" content="Tests that color is correctly inherited in the presence of visited link"/>
        #|  <a xlink:href="">
        #|    <rect width="100" height="100"></rect>
        #|  </a>
        #|</svg>
        #|
      ),
      (
        #|<svg width="100" height="100" fill="green" xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100"></rect>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "styling/css-var-on-length-attributes-03.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Usage of css var() with default fallback on svg width and height attributes (units specified)</title>
        #|  <html:link rel="author" title="Divyansh Mangal" href="mailto:dmangal@microsoft.com"/>
        #|  <html:link rel="match" href="../embedded/reference/green-rect-100x100.svg"/>
        #|  <rect width="var(--length,100px)" height="var(--length,100px)" fill="green"/>
        #|</svg>
        #|
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" fill="green"/>
        #|</svg>
        #|
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "styling/image-sizing-min-content.tentative.svg",
      (
        #|<svg xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height (in auto) as presentation attributes on image</title>
        #|  <html:link rel="help" href="https://svgwg.org/svg2-draft/styling.html#TermPresentationAttribute"/>
        #|  <html:link rel="match" href="image-sizing-min-content-expected.svg" />
        #|  <image width="128" height="128" style="width:min-content;height:min-content" href="/images/green-256x256.png"/>
        #|</svg>
      ),
      (
        #|<svg xmlns="http://www.w3.org/2000/svg">
        #|  <image width="128" height="128" style="width:auto;height:auto" href="/images/green-256x256.png"/>
        #|</svg>
      ),
      300,
      150,
      -1,
      -1,
    ),
    case(
      "styling/outermost-svg-sizing-viewport-units.svg",
      (
        #|<svg style="width:10vw;height:10vh;" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height (in viewport units) as presentation attributes on outermost svg</title>
        #|  <html:link rel="help" href="https://svgwg.org/svg2-draft/styling.html#TermPresentationAttribute"/>
        #|  <html:link rel="match"  href="outermost-svg-sizing-viewport-units-expected.svg" />
        #|    <rect width="100%" height="100%" fill="green" />
        #|</svg>
        #|
      ),
      (
        #|<svg width="10%" height="10%" xmlns="http://www.w3.org/2000/svg">
        #|    <rect width="100%" height="100%" fill="green" />
        #|</svg>
        #|
      ),
      10,
      10,
      -1,
      -1,
    ),
    case(
      "styling/rect-sizing-viewport-units.svg",
      (
        #|<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <title>Width and Height (in viewport units) as presentation attributes on rect</title>
        #|  <html:link rel="help" href="https://svgwg.org/svg2-draft/styling.html#TermPresentationAttribute"/>
        #|  <html:link rel="match"  href="rect-sizing-viewport-units-expected.svg" />
        #|    <rect style="width:10vw;height:10vh;" fill="green" />
        #|</svg>
        #|
      ),
      (
        #|<svg width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
        #|    <rect width="10%" height="10%" fill="green" />
        #|</svg>
      ),
      100,
      100,
      -1,
      -1,
    ),
    case(
      "styling/stroke-color-inherit-link-visited.svg",
      (
        #|<svg width="100" height="100" stroke="red" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:html="http://www.w3.org/1999/xhtml">
        #|  <html:link rel="help" href="https://developer.mozilla.org/en-US/docs/Web/CSS/Privacy_and_the_:visited_selector"/>
        #|  <html:link rel="match" href="stroke-color-inherit-link-visited-ref.svg"/>
        #|  <html:meta name="assert" content="Tests that stroke is correctly inherited in the presence of visited link"/>
        #|  <a xlink:href="">
        #|    <rect width="100" height="100" stroke-width="5"></rect>
        #|  </a>
        #|</svg>
        #|
      ),
      (
        #|<svg width="100" height="100" stroke="red" fill="none" xmlns="http://www.w3.org/2000/svg">
        #|  <rect width="100" height="100" stroke-width="5"></rect>
        #|</svg>
        #|
      ),
      100,
      100,
      -1,
      -1,
    ),
  ]
}

///|
fn case(
  name : String,
  test_svg : String,
  ref_svg : String,
  width : Int,
  height : Int,
  max_diff : Int,
  max_pixels : Int,
) -> WptCase {
  { name, test_svg, ref_svg, width, height, max_diff, max_pixels }
}
