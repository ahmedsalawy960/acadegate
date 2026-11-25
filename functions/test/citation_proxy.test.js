"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { ALLOWED_HOSTS } = require("../citation_proxy");

// The Dart CitationHttp allowlist forwards these hosts to the proxy on web;
// if the proxy rejects them the features fail closed (empty results) with no
// visible error. Keep the two lists in sync.
test("proxy allows every host the app's research sources call on web", () => {
  const required = [
    // Pre-existing research sources.
    "api.crossref.org",
    "api.openalex.org",
    "api.semanticscholar.org",
    "www.ebi.ac.uk",
    "pub.orcid.org",
    "query.wikidata.org",
    // Unpaywall (was missing before this patch).
    "api.unpaywall.org",
    // OpenAIRE graph (patch 17).
    "api.openaire.eu",
    // OpenCitations COCI counts (patch 18).
    "opencitations.net",
    // Dataset search (patch 20).
    "api.datacite.org",
    "zenodo.org",
  ];
  for (const host of required) {
    assert.ok(ALLOWED_HOSTS.has(host), `${host} must be proxy-allowed`);
  }
});

test("proxy still allows serpapi for scholar search", () => {
  assert.ok(ALLOWED_HOSTS.has("serpapi.com"));
});
