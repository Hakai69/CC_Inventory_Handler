local prefix = ... and (...):match('(.-)[^%.]+$') or ''
return require(prefix .. 'item_quality_handler.item_quality_handler')