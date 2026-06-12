///|
test "format failures emits json" {
  let report = format_failures(["case one", "case two"])
  assert_true(@json.valid(report))
  let parsed = @json.parse(report)
  let decoded : AbnormalCasesReport = @json.from_json(parsed)
  assert_eq(decoded.abnormal_cases.length(), 2)
  assert_eq(decoded.abnormal_cases[0].summary, "case one")
  assert_eq(decoded.abnormal_cases[1].summary, "case two")
}
