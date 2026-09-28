//
//  ShellText.swift
//  ShizukuRender
//
//  M5.6 WP-7a: the system-shell string table, routed by *build* language
//  (HANDOVER §38.0 D1 — no runtime switching). Every shell surface (title menu,
//  ESC six-item menu, confirm dialogs, slot picker) resolves through here:
//
//   * `.jp` rows are the exact `MenuStrings` leaf-code arrays the dot-matrix
//     renderer has always drawn — the JP path stays byte-identical (防回归).
//   * `.zh` rows are Unicode strings drawn with the native anti-aliased CJK
//     font (`drawNativeText`), because sizfont/KNJ carries no simplified glyphs.
//
//  Wording sources (research/cn_dump/cn_menu_strings.txt UTF-16LE dump +
//  research/localization_20260924/patch_installer_gbk_strings.txt):
//  verbatim CN-patch strings where they exist (结束游戏 / 确定 / 取消 /
//  即将退出游戏。/ 确定吗？), established HANDOVER terminology elsewhere
//  (しおり→书签, クイックセーブ→快速存档). The choice-menu (choices) text is
//  corpus-dependent and stays on the JP path until WP-5/WP-7b.
//

import Foundation
import ShizukuCore

/// One menu row: either the native leaf-code dot matrix (JP) or a Unicode
/// string rendered with the system CJK font (ZH). Drawing and hit-testing both
/// consume this type, so a click can only land on a row that was painted.
public enum MenuRow: Equatable {
    case leaves([Int])
    case native(String)

    public var leafCodes: [Int]? {
        if case .leaves(let l) = self { return l }
        return nil
    }
    public var nativeText: String? {
        if case .native(let s) = self { return s }
        return nil
    }
}

/// Which confirmation dialog is up — mirrors `MetalGameView`'s pendingConfirm.
public enum ShellConfirmKind {
    case load, save, end
}

public enum ShellText {
    /// Font size (native px) for ZH menu rows; matches the CN text layer body
    /// size in `drawCNTextLayer` so shell and story read as one typeface.
    public static let nativeMenuFontSize: CGFloat = 20

    // MARK: - Title menu (5 rows, lines 7..11)

    public static func titleRows(_ lang: GameLanguage) -> [MenuRow] {
        switch lang {
        case .jp:
            return [.leaves(MenuStrings.newGame), .leaves(MenuStrings.continueGame),
                    .leaves(MenuStrings.recallMode), .leaves(MenuStrings.endingsList),
                    .leaves(MenuStrings.quit)]
        case .zh:
            return [.native("从头开始"), .native("继续游戏"), .native("回想模式"),
                    .native("结局列表"), .native("结束游戏")]
        }
    }

    // MARK: - ESC system menu (6 rows, lines 3..8, sizuku_menu.c order)

    public static func escRows(_ lang: GameLanguage) -> [MenuRow] {
        switch lang {
        case .jp:
            return SceneComposer.escMenuItems.map { MenuRow.leaves($0) }
        case .zh:
            return [.native("隐藏文字"), .native("载入游戏"), .native("存档游戏"),
                    .native("场景回想"), .native("返回上一个选项"), .native("结束游戏")]
        }
    }

    // MARK: - Confirm dialogs (header line 4, question 5, yes/no 6..7)

    /// The yes/no pair. CN patch literals: 确定 / 取消.
    public static func confirmRows(_ lang: GameLanguage) -> [MenuRow] {
        switch lang {
        case .jp:
            return [.leaves(MenuStrings.yes), .leaves(MenuStrings.no)]
        case .zh:
            return [.native("确定"), .native("取消")]
        }
    }

    public static func confirmQuestion(_ lang: GameLanguage) -> MenuRow {
        switch lang {
        case .jp: return .leaves(MenuStrings.confirmQuestion)
        case .zh: return .native("确定吗？")   // GBK dump verbatim
        }
    }

    public static func confirmHeader(_ kind: ShellConfirmKind, _ lang: GameLanguage) -> MenuRow {
        switch lang {
        case .jp:
            switch kind {
            case .load: return .leaves(MenuStrings.confirmLoad)
            case .save: return .leaves(MenuStrings.confirmSave)
            case .end:  return .leaves(MenuStrings.confirmEnd)
            }
        case .zh:
            switch kind {
            case .load: return .native("即将载入。")
            case .save: return .native("即将存档。")
            case .end:  return .native("即将退出游戏。")   // GBK dump verbatim
            }
        }
    }

    // MARK: - Slot picker

    public static func slotHeader(save: Bool, _ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return save ? "セーブするしおりを選択してください" : "ロードするデータを選択してください"
        case .zh: return save ? "请选择要存档的书签" : "请选择要载入的数据"
        }
    }

    /// Row label for a picker slot (0 = quicksave, 1..6 = bookmarks).
    public static func slotLabel(slot: Int, _ lang: GameLanguage) -> String {
        switch lang {
        case .jp:
            return slot == 0 ? "クイックセーブ" : "しおり　\(slot)"
        case .zh:
            return slot == 0 ? "快速存档" : "书签 \(slot)"
        }
    }

    public static func slotEmpty(_ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return UIText.slotEmpty          // （から）
        case .zh: return "（空）"
        }
    }

    public static func slotHint(_ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return UIText.slotHint           // クリック決定　ＥＳＣで戻る
        case .zh: return "点击确定　ESC返回"
        }
    }

    /// DateFormatter pattern for the picker's timestamp column. JP keeps the
    /// original 時/分 reading; ZH uses the colon form the CN patch ships.
    public static func slotDateFormat(_ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return "MM月dd日 HH時mm"
        case .zh: return "MM月dd日 HH:mm"
        }
    }

    // MARK: - Endings list (WP-9)

    public static func endingsTitle(_ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return UIText.endingsTitle
        case .zh: return "结局达成状况　点击返回"
        }
    }

    public static func endingsStatus(cleared: Bool, _ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return cleared ? UIText.endingsCleared : UIText.endingsLocked
        case .zh: return cleared ? "○ 已达成" : "－ 未达成"
        }
    }

    // MARK: - 回想モード gallery (WP-9)

    public static func galleryHeader(_ lang: GameLanguage) -> MenuRow {
        switch lang {
        case .jp: return .leaves(MenuStrings.recallMode)
        case .zh: return .native("回想模式")
        }
    }

    public static func galleryHint(_ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return UIText.galleryHint
        case .zh: return "点击放大　方向键移动"
        }
    }

    public static func galleryPageLabel(_ n: Int, total: Int, _ lang: GameLanguage) -> String {
        switch lang {
        case .jp: return UIText.galleryPageLabel(n, total)
        case .zh: return "第\(n)页（共\(total)页）"
        }
    }

    // MARK: - 音楽モード room (WP-9)

    public static func musicStrings(_ lang: GameLanguage) -> MusicStrings {
        switch lang {
        case .jp:
            return MusicStrings(title: "音楽モード", playingLabel: "演奏中の曲",
                                selectedLabel: "選択中の曲", creditLabel: "作曲・編曲",
                                buttons: ["前の曲", "演奏", "次の曲"],
                                exitHint: "右クリックまたはＥＳＣで終了")
        case .zh:
            return MusicStrings(title: "音乐模式", playingLabel: "正在播放",
                                selectedLabel: "选中曲目", creditLabel: "作曲・编曲",
                                buttons: ["上一首", "播放", "下一首"],
                                exitHint: "右键点击或按ESC退出")
        }
    }

    public struct MusicStrings {
        public let title: String
        public let playingLabel: String
        public let selectedLabel: String
        public let creditLabel: String
        public let buttons: [String]
        public let exitHint: String
    }

    // MARK: - Toast banner (WP-9)

    /// Map a JP toast string (the internal key — call sites are unchanged) to the
    /// ZH surface string. Dynamic parts (ON/OFF, slot numbers, key labels) are
    /// re-inserted around the translated frame.
    public static func toastCN(_ jp: String) -> String {
        // The JP frame keeps the slot name as `しおり N` / `クイックセーブ`; leaving it
        // verbatim would print kana inside an otherwise Chinese banner.
        func suffix(_ jp: String, _ zh: String) -> String {
            guard let r = jp.firstIndex(of: "["), jp.hasSuffix("]") else { return zh }
            let tail = String(jp[r...])
                .replacingOccurrences(of: "クイックセーブ", with: "快速存档")
                .replacingOccurrences(of: "しおり", with: "书签")
            return zh + " " + tail
        }
        switch jp {
        case _ where jp.hasPrefix("既読テキスト自動スキップ"): return suffix(jp, "已读文本自动跳过")
        case _ where jp.hasPrefix("早送り未読スキップ"): return suffix(jp, "快进时连未读一并跳过")
        case _ where jp.hasPrefix("画面エフェクト"): return suffix(jp, "画面特效")
        case _ where jp.hasPrefix("早送り速度"): return suffix(jp, "快进速度")
        case _ where jp.hasPrefix("スキップモード"): return suffix(jp, "跳过模式")
        case _ where jp.hasPrefix("スキップキーを"):
            guard let end = jp.firstIndex(of: "に") else { return jp }
            let key = jp[jp.index(jp.startIndex, offsetBy: "スキップキーを ".count)
                            ..< jp.index(before: end)]
                .trimmingCharacters(in: .whitespaces)
            return "跳过键已改为 \(key)"
        case _ where jp.hasPrefix("セーブデータをロードしました"): return suffix(jp, "已载入存档")
        case "セーブデータが見つかりません": return "未找到存档"
        case "セーブデータがありません": return "没有存档数据"
        case _ where jp.hasPrefix("クイックセーブ完了"): return suffix(jp, "快速存档完成")
        case "セーブに失敗しました": return "存档失败"
        case "未読です。設定で未読スキップを有効に": return "这是未读文本。请在设置中开启未读跳过"
        case "一つ前の選択肢に戻りました": return "已返回上一个选项"
        case "選択肢の保存点はありません": return "没有可返回的选项存档点"
        case "ロードに失敗しました": return "载入失败"
        case _ where jp.hasPrefix("セーブしました"): return suffix(jp, "已保存")
        case _ where jp.hasSuffix("は空です"):
            return jp.replacingOccurrences(of: "は空です", with: "为空")
        default: return jp
        }
    }

    // MARK: - Window chrome (WP-9)

    public static func windowGameTitle(_ lang: GameLanguage) -> String {
        lang == .zh ? "雫～shizuku～" : "雫～しずく～"
    }
}
