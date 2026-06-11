import 'dart:html' as html;
import 'dart:convert';

void downloadCsvWebLocally(String content, String fileName) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  
  html.Url.revokeObjectUrl(url);
}
