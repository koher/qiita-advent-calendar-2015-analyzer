import Foundation

import Alamofire
import Argo
import Curry
import Fuzi
import PromiseK
import Runes

///// Alamofire を Promise 化するための拡張 /////

extension Request {
    public func promisedResponse(queue queue: dispatch_queue_t? = nil)
        -> Promise<(NSURLRequest?, NSHTTPURLResponse?, NSData?, NSError?)> {
        return Promise { resolve in
            self.response(queue: queue) { resolve(pure($0)) }
        }
    }

    public func promisedResponseJSON(options options: NSJSONReadingOptions = .AllowFragments)
        -> Promise<Response<AnyObject, NSError>> {
        return Promise { resolve in
            self.responseJSON(options: options) { resolve(pure($0)) }
        }
    }
    
}

///// 非同期処理中にプログラムが終了してしまわないように Promise を同期的に待たせるための拡張 /////

extension Promise {
    func wait() {
        var finished = false
        self.flatMap { (value: T) -> Promise<()> in
            finished = true
            return Promise<()>()
        }
        while (!finished){
            NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.1))
        }
    }
}

///// このスクリプトで利用するデータ型 /////

// 投稿
struct Item: Decodable {
    let tags: [String]
    let stockCount: Int
    
    static func decode(j: JSON) -> Decoded<Item> { // Argo のデコード用
        let tags: Decoded<[String]> = (j <|| "tags")
            .flatMap { tagJsons in sequence(tagJsons.map { $0 <| "url_name" }) }
        return curry(Item.init)
            <^> tags
            <*> j <| "stock_count"
    }
}

// ユーザー
struct User {
    let id: String
    let items: [Item]
    
    var stockCount: Int {
        return items.reduce(0) { $0 + $1.stockCount } // 各投稿のストック数の合計
    }
    
    var score: Float {
        return items.count == 0 ? 0.0 : Float(stockCount) / Float(items.count)
    }
}

///// 処理の本体 /////

// コマンドライン引数を取得
let calendarName = Process.arguments[1]
let tag = Process.arguments[2]

// 1. カレンダーのページの HTML を Alamofire で取得
let html: Promise<String?> = Alamofire.request(Method.GET, "http://qiita.com/advent-calendar/2015/\(calendarName)")
    .promisedResponse().map { response in
    switch response {
    case let (_, _, .Some(data), _):
        return NSString(data: data, encoding: NSUTF8StringEncoding).map { $0 as String }
    default:
        return nil
    }
}

// 2. Fuzi で HTML から参加者のユーザー ID をスクレイピング
let userIds: Promise<[String]?> = html.map {
    $0.flatMap { html in // nil でない場合
        // HTML 文字列を XMLDocument に変換
        try? XMLDocument(string: html)
    // XMLDocument から CSS セレクタで要素を取得
    }?.css(".adventCalendarCalendar_day .adventCalendarCalendar_author a")
        // ユーザー ID を含んだ href 属性を取得
        .map { $0.attributes["href"]! }
        // 1 文字目の "/" を除去してユーザー ID に変換
        .map { $0[$0.startIndex.successor()..<$0.endIndex] }
}

// 3. Alamofire で Qiita API を叩いて各参加者の情報を取得し Argo でデコード
let users: Promise<[User]?> = userIds >>- { $0.map { userIds in // nil でない場合
    // ユーザーの投稿を一人ずつダウンロード
    userIds.reduce(Promise([])) { users, userId in
        users >>- { usersOrNil -> Promise<[User]?> in
            Alamofire.request(Method.GET, "https://qiita.com/api/v1/users/\(userId)/items", parameters: ["per_page": 100])
                // Qiita API でユーザーの投稿一覧を取得
                .promisedResponseJSON().map { response in
                let userOrNil: [User]? = response.result.value
                    // JSON をデコードして [Item] を取得
                    .flatMap { decode($0) }
                    // [Item] から指定したタグを含まないものを除去
                    .map { items in items.filter { $0.tags.contains(tag) } }
                    // [Item] を User に変換し、連結するために [User] に変換
                    .map { items in [User(id: userId, items: items)] }
                // ダウンロード済みの [User] と連結
                return curry(+) <^> usersOrNil <*> userOrNil
            }
        }
    }
} }

// 4. 得られた情報を元に戦力を計算して出力
let end: Promise<()> = users.map {
    if let users = $0 {
        print("| 担当日 | ユーザー | 総ストック数 | 投稿数 | 平均ストック数 |")
        print("|:---|:--:|---:|---:|---:|")
        
        zip(1...25, users).forEach { date, user in
            print("| 12/\(date) | @\(user.id) | \(user.stockCount) | \(user.items.count) | \(user.score) |")
        }
        
        let score = users.reduce(0.0) { $0 + $1.score }
        print("| 戦力 | | | | \(score) |")
    } else {
        print("エラーが発生しました。")
    }
}

// 非同期処理が完了するまで待機
end.wait()
