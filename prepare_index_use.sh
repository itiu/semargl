rm indexes
#grep 'B get from index SPO:' app.log | cut -c 36- | sort | uniq >>indexes
#grep 'B get from index S:' app.log | cut -c 36- | sort | uniq >>indexes
grep 'B get from index P:' app.log | cut -c 36- | sort | uniq >>indexes
#grep 'B get from index O:' app.log | cut -c 36- | sort | uniq >>indexes
grep 'B get from index SP:' app.log | cut -c 36- | sort | uniq >>indexes
grep 'B get from index PO:' app.log | cut -c 36- | sort | uniq >>indexes
grep 'B get from index OP:' app.log | cut -c 36- | sort | uniq >>indexes


