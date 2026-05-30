///|
/// Curated subset of the [Mozilla Public Suffix List](https://publicsuffix.org/list/).
///
/// Full PSL has ~10000 rules across ICANN and PRIVATE sections; embedding
/// the whole list as MoonBit data is tracked separately. This subset
/// covers the multi-level suffixes Crater currently exercises plus the
/// well-known cases named in GitHub issue #149 (`co.uk`, `co.jp`,
/// `github.io`).
///
/// Refresh policy: this list is a hand-curated extract. To regenerate
/// the subset from a fresh PSL snapshot, pull
/// https://publicsuffix.org/list/public_suffix_list.dat and keep the
/// entries below in the order documented here. New entries should be
/// added when a Crater fixture or downstream consumer surfaces a host
/// whose registrable domain would be misclassified by the heuristic
/// fallback in `registrable_domain_heuristic`.

///|
/// Literal multi-level public suffixes that match exactly. A host
/// `*.example.<rule>` reduces to `example.<rule>` as its registrable
/// domain (eTLD+1).
pub fn psl_literal_rules() -> Array[String] {
  [
    // ICANN — second-level country code suffixes
    "co.uk", "org.uk", "net.uk", "ac.uk", "gov.uk", "nhs.uk", "police.uk", "co.jp",
    "ad.jp", "ac.jp", "ed.jp", "go.jp", "gr.jp", "lg.jp", "ne.jp", "or.jp", "co.kr",
    "ac.kr", "go.kr", "or.kr", "ne.kr", "re.kr", "pe.kr", "com.au", "net.au", "org.au",
    "edu.au", "gov.au", "asn.au", "id.au", "com.br", "net.br", "org.br", "gov.br",
    "edu.br", "com.cn", "net.cn", "org.cn", "gov.cn", "edu.cn", "ac.cn", "mil.cn",
    "com.mx", "net.mx", "org.mx", "gob.mx", "edu.mx", "co.nz", "net.nz", "org.nz",
    "ac.nz", "govt.nz", "school.nz", "co.za", "net.za", "org.za", "gov.za", "edu.za",
    "ac.za", "co.in", "net.in", "org.in", "gov.in", "ac.in", "edu.in", "ind.in",
    "com.sg", "net.sg", "org.sg", "gov.sg", "edu.sg", "com.tw", "net.tw", "org.tw",
    "gov.tw", "edu.tw", "com.hk", "net.hk", "org.hk", "gov.hk", "edu.hk", "co.id",
    "net.id", "or.id", "go.id", "ac.id", "com.tr", "net.tr", "org.tr", "gov.tr",
    "edu.tr", "com.ar", "com.pe", "com.co", "com.ec", "com.uy", "com.ve", "co.il",
    "ac.il", "gov.il", "co.th", "ac.th", "go.th", "co.ma", "co.ke", "co.ug", "co.tz",
    // PRIVATE — common hosted-app suffixes Crater fixtures may exercise
     "github.io", "vercel.app", "netlify.app", "pages.dev", "cloudfront.net", "amazonaws.com",
    "s3.amazonaws.com", "herokuapp.com", "fly.dev", "azurewebsites.net",
  ]
}

///|
/// Wildcard suffixes: the entry `co` in this list represents a PSL rule
/// `*.co`, meaning any single label preceding `.co` (e.g.
/// `example.co`) is itself a public suffix. Only one well-known
/// wildcard rule (`*.ck` from the Cook Islands) is included — extend
/// when a Crater fixture surfaces the need.
pub fn psl_wildcard_rules() -> Array[String] {
  // Each entry is the suffix after the leading "*." stripped, e.g.
  // PSL "*.ck" -> "ck" here. Empty by default; populate when needed.
  []
}

///|
/// Exception rules: PSL `!city.kawasaki.jp` excludes `city.kawasaki.jp`
/// from a wildcard `*.kawasaki.jp` match. Empty by default; the
/// curated subset above only includes literal rules, so no exceptions
/// are needed yet.
pub fn psl_exception_rules() -> Array[String] {
  []
}
