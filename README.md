# Qiita Advent Calendar 2015 Analyzer

The script to estimate total stock counts of calendars in [Qiita Advent Calendar 2015](http://qiita.com/advent-calendar/2015).

It is also a sample code of functional programming in Swift using the following libraries.

- [Alamofire](https://github.com/Alamofire/Alamofire)
- [Fuzi](https://github.com/cezheng/Fuzi)
- [Argo](https://github.com/thoughtbot/Argo)
- [PromiseK](https://github.com/koher/PromiseK/)
- [Runes](https://github.com/thoughtbot/runes)
- [Curry](https://github.com/thoughtbot/Curry)

## Installation of Libraries

```
carthage bootstrap --platform mac
```

## Run

### Syntax

```
swift -F Carthage/Build/Mac/ -I /usr/include/libxml2 main.swift <calendar-name> <tag-name>
```

`<calendar-name>` is the last component of the URL of the calendar page. For example, `<calendar-name>` of http://qiita.com/advent-calendar/2015/go2 is `go2`.

`<tag-name>` is the last component of the URL of the tag page in __lowercase__. For example, `<tag-name>` of http://qiita.com/tags/Go is `Go`

### Example

```
swift -F Carthage/Build/Mac/ -I /usr/include/libxml2 main.swift go2 go
```
