"use strict";
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { crc32, gunzipSync } = require("node:zlib");
const CFB = require("cfb");
const { validateAdvisorFile, AdvisorFileError } = require("../advisor_file_validation");
const legacy = require("./fixtures/advisor-office.json");

// Minimal ZIP writer keeps tests offline and avoids another production dependency.
function zip(files, flags = 0) {
  const chunks = [], directory = []; let offset = 0;
  for (const [name, value] of files) {
    const n = Buffer.from(name), b = Buffer.from(value);
    const local = Buffer.alloc(30); local.writeUInt32LE(0x04034b50);
    local.writeUInt16LE(20, 4); local.writeUInt16LE(flags, 6);
    local.writeUInt32LE(crc32(b), 14); local.writeUInt32LE(b.length, 18);
    local.writeUInt32LE(b.length, 22); local.writeUInt16LE(n.length, 26);
    const central = Buffer.alloc(46); central.writeUInt32LE(0x02014b50);
    central.writeUInt16LE(20, 4); central.writeUInt16LE(20, 6);
    central.writeUInt16LE(flags, 8); central.writeUInt32LE(crc32(b), 16);
    central.writeUInt32LE(b.length, 20); central.writeUInt32LE(b.length, 24);
    central.writeUInt16LE(n.length, 28); central.writeUInt32LE(offset, 42);
    chunks.push(local, n, b); directory.push(central, n);
    offset += local.length + n.length + b.length;
  }
  const cd = Buffer.concat(directory), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50); end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10); end.writeUInt32LE(cd.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...chunks, cd, end]);
}
const spec = {
  docx: ["word/document.xml", "document", "wordprocessingml", "wordprocessingml.document"],
  xlsx: ["xl/workbook.xml", "workbook", "spreadsheetml", "spreadsheetml.sheet"],
  pptx: ["ppt/presentation.xml", "presentation", "presentationml", "presentationml.presentation"],
};
function parts(ext, body) {
  const [path, root, ns, type] = spec[ext];
  return [
    [path, body ?? `<${root} xmlns="http://schemas.openxmlformats.org/${ns}/2006/main"/>`],
    ["[Content_Types].xml", `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Override PartName="/${path}" ContentType="application/vnd.openxmlformats-officedocument.${type}.main+xml"/></Types>`],
    ["_rels/.rels", `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="${path}"/></Relationships>`],
  ];
}
const rejected = (ext, b) => assert.rejects(validateAdvisorFile(ext, b), AdvisorFileError);
for (const ext of Object.keys(spec)) {
  test(`${ext}: genuine generated document`, async () => {
    const b = gunzipSync(Buffer.from(legacy[ext], "base64"));
    assert.ok((await validateAdvisorFile(ext, b)).inlineData);
  });
  test(`${ext}: package structure and XML accepted`, async () => {
    assert.ok((await validateAdvisorFile(ext, zip(parts(ext)))).inlineData);
  });
  for (const [label, xml] of [["non-XML", "fake"], ["malformed", "<bad>"], ["wrong namespace", "<document/>"], ["DTD", '<!DOCTYPE a [<!ENTITY x "abc">]><a>&x;</a>']]) {
    test(`${ext}: rejects ${label}`, () => rejected(ext, zip(parts(ext, xml))));
  }
  test(`${ext}: requires type declaration and package relationship`, async () => {
    await rejected(ext, zip(parts(ext).slice(0, 1)));
    const p = parts(ext); p[1][1] = p[1][1].replace("main+xml", "wrong+xml");
    await rejected(ext, zip(p));
    const r = parts(ext); r[2][1] = r[2][1].replace('Target=', 'TargetMode="External" Target=');
    await rejected(ext, zip(r));
  });
}
test("ZIP rejects CRC corruption, duplicate paths, traversal, encryption, and macros", async () => {
  const p = parts("docx"), b = zip(p); b[30 + Buffer.byteLength(p[0][0])] ^= 1;
  await rejected("docx", b);
  await rejected("docx", zip([...p, p[0]]));
  await rejected("docx", zip([...p, ["../evil", "x"]]));
  await rejected("docx", zip(p, 1));
  await rejected("docx", zip([...p, ["word/vbaProject.bin", "x"]]));
});
test("ZIP rejects excessive entries and expanded size", async () => {
  await rejected("docx", zip([...parts("docx"), ...Array.from({length: 2000}, (_, i) => [`x${i}`, ""])]));
  const b = zip(parts("docx"));
  const cd = b.indexOf(Buffer.from("504b0102", "hex")); b.writeUInt32LE(33 * 1024 * 1024, cd + 24);
  await rejected("docx", b);
});
for (const ext of ["txt", "md", "csv", "tsv"]) {
  test(`${ext}: tags and Arabic remain inert text`, async () => {
    for (const text of ["<html>نص عربي</html>", '<?xml version="1.0"?><sample/>', "MZ research notes"]) {
      assert.equal((await validateAdvisorFile(ext, Buffer.from(text))).text, text);
    }
  });
}
test("UTF-8 BOM and both UTF-16 byte orders", async () => {
  const text = "<p>العربية 😀</p>";
  const le = Buffer.from(text, "utf16le"); const be = Buffer.from(le).swap16();
  for (const b of [Buffer.concat([Buffer.from([239,187,191]), Buffer.from(text)]), Buffer.concat([Buffer.from([255,254]), le]), Buffer.concat([Buffer.from([254,255]), be])]) {
    assert.equal((await validateAdvisorFile("txt", b)).text, text);
  }
  await rejected("txt", Buffer.from([255,254,1]));
  await rejected("txt", Buffer.from([0xc3,0x28]));
  await rejected("txt", Buffer.from([0,1,2]));
});
for (const ext of ["doc", "xls", "ppt"]) {
  test(`${ext}: genuine LibreOffice export`, async () => {
    const b = gunzipSync(Buffer.from(legacy[ext], "base64"));
    assert.ok((await validateAdvisorFile(ext, b)).inlineData);
    await rejected(ext, b.subarray(0, b.length - 1));
    const corrupt = Buffer.from(b); corrupt.writeUInt16LE(0, 30);
    await rejected(ext, corrupt);
    for (const other of ["doc", "xls", "ppt"].filter(x => x !== ext)) await rejected(other, b);
  });
}
test("OLE marker alone, fake Workbook stream, and encryption are rejected", async () => {
  const fake = Buffer.alloc(512); Buffer.from("d0cf11e0a1b11ae1", "hex").copy(fake); fake.write("Workbook", 100);
  await rejected("xls", fake);
  const f = CFB.utils.cfb_new(); CFB.utils.cfb_add(f, "Workbook", Buffer.from("not BIFF"));
  await rejected("xls", CFB.write(f, {type: "buffer"}));
  CFB.utils.cfb_add(f, "EncryptionInfo", Buffer.from("encrypted"));
  await rejected("xls", CFB.write(f, {type: "buffer"}));
});
test("legacy Office rejects damaged document structures and password flags", async () => {
  for (const [ext, streamName, edit] of [
    ["doc", "WordDocument", b => b.writeUInt16LE(0, 0)],
    ["doc", "WordDocument", b => b.writeUInt16LE(b.readUInt16LE(10) | 0x100, 10)],
    ["xls", "Workbook", b => b.writeUInt16LE(0x2f, 0)],
    ["xls", "Workbook", b => b.writeUInt16LE(0xffff, 2)],
    ["ppt", "Current User", b => b.writeUInt32LE(0xf3d1c4df, 12)],
    ["ppt", "PowerPoint Document", b => b.writeUInt32LE(0xffffffff, 4)],
  ]) {
    const f = CFB.read(gunzipSync(Buffer.from(legacy[ext], "base64")), {type: "buffer"});
    edit(CFB.find(f, streamName).content);
    await rejected(ext, CFB.write(f, {type: "buffer"}));
  }
});
test("empty, unsupported, oversized and binary masquerading as text", async () => {
  await rejected("txt", Buffer.alloc(0));
  await rejected("exe", Buffer.from("x"));
  await rejected("txt", Buffer.alloc(10 * 1024 * 1024 + 1, 65));
  await rejected("txt", zip(parts("docx")));
});
