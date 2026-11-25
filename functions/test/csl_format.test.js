"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  formatBibliography,
  SUPPORTED_STYLES,
  stripMarkup,
} = require("../csl_format");

const ITEM = {
  id: "10.2134/agronj1994",
  type: "article-journal",
  title: "Drip irrigation and soybean yield",
  DOI: "10.2134/agronj1994.00021962008600050009x",
  "container-title": "Journal of Nematology",
  issued: { "date-parts": [[2011]] },
  author: [
    { family: "Weaver", given: "D B" },
    { literal: "R Rodriguez-Kabana" },
  ],
  URL: "https://doi.org/10.2134/agronj1994.00021962008600050009x",
};

test("APA 7 formats an article with authors, year, journal, DOI", () => {
  const entries = formatBibliography({
    items: [ITEM],
    style: "apa",
    locale: "en",
  });
  assert.equal(entries.length, 1);
  const text = entries[0].text;
  assert.match(text, /Weaver/);
  assert.match(text, /2011/);
  assert.match(text, /Drip irrigation and soybean yield/);
  assert.match(text, /Journal of Nematology/);
  assert.match(text, /10\.2134\/agronj1994/);
});

test("Vancouver (elsevier-vancouver) numbers the entry and keeps authors", () => {
  const entries = formatBibliography({
    items: [ITEM],
    style: "elsevier-vancouver",
    locale: "en",
  });
  assert.equal(entries.length, 1);
  assert.match(entries[0].text, /Weaver/);
  assert.match(entries[0].text, /2011/);
});

test("Arabic locale renders without error", () => {
  const entries = formatBibliography({
    items: [ITEM],
    style: "apa",
    locale: "ar",
  });
  assert.equal(entries.length, 1);
  assert.ok(entries[0].text.length > 20);
});

test("every bundled style loads and formats", () => {
  for (const style of SUPPORTED_STYLES) {
    const entries = formatBibliography({
      items: [ITEM],
      style,
      locale: "en",
    });
    assert.equal(entries.length, 1, `${style} should format one item`);
    assert.ok(entries[0].text.includes("Weaver"), `${style} keeps author`);
  }
});

test("rejects unknown styles, empty items, and items without titles", () => {
  assert.throws(
    () => formatBibliography({ items: [ITEM], style: "nope", locale: "en" }),
    /invalid-argument: Unsupported style/,
  );
  assert.throws(
    () => formatBibliography({ items: [], style: "apa", locale: "en" }),
    /invalid-argument: items must be/,
  );
  assert.throws(
    () =>
      formatBibliography({
        items: [{ id: "x", title: " " }],
        style: "apa",
        locale: "en",
      }),
    /invalid-argument: each item needs/,
  );
});

test("over-50 item batches are rejected", () => {
  const items = Array.from({ length: 51 }, (_, i) => ({
    id: `id-${i}`,
    title: `T${i}`,
  }));
  assert.throws(
    () => formatBibliography({ items, style: "apa", locale: "en" }),
    /invalid-argument/,
  );
});

test("stripMarkup removes tags and decodes entities", () => {
  assert.equal(
    stripMarkup('<div class="csl-entry"><i>Nature</i> &amp; co</div>'),
    "Nature & co",
  );
});
