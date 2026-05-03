//
//  HiddenWebViewCommentSubmissionClient.swift
//  nodeseek
//

import Foundation

struct HiddenWebViewCommentSubmissionClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitComment(postID: Int, content: String, referer: URL) async throws -> CommentAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 模拟评论提交: postID=\(postID), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitComment(
                pageURL: referer,
                content: content,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

struct HiddenWebViewPostCollectionClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitCollection(postID: Int, action: String, referer: URL) async throws -> PostCollectionAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 提交收藏动作: postID=\(postID), action=\(action), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitCollection(
                pageURL: referer,
                postID: postID,
                action: action,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

struct HiddenWebViewCommentUpvoteClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitUpvote(commentID: Int, action: String, referer: URL) async throws -> CommentUpvoteAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 提交评论点赞: commentID=\(commentID), action=\(action), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitCommentUpvote(
                pageURL: referer,
                commentID: commentID,
                action: action,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

struct HiddenWebViewPostUpvoteClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitUpvote(postID: Int, action: String, referer: URL) async throws -> PostUpvoteAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 提交帖子点赞: postID=\(postID), action=\(action), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitPostUpvote(
                pageURL: referer,
                postID: postID,
                action: action,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

struct HiddenWebViewCommentDislikeClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitDislike(commentID: Int, action: String, referer: URL) async throws -> CommentDislikeAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 提交评论反对: commentID=\(commentID), action=\(action), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitCommentDislike(
                pageURL: referer,
                commentID: commentID,
                action: action,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

struct HiddenWebViewPostDislikeClient {
    private let timeoutInterval: TimeInterval

    init(timeoutInterval: TimeInterval = 20) {
        self.timeoutInterval = timeoutInterval
    }

    func submitDislike(postID: Int, action: String, referer: URL) async throws -> PostDislikeAutomationResponse {
        let requestLock = HiddenWebViewRequestLock.shared
        await requestLock.acquire()
        AppLog.info(.webView, "准备通过隐藏 WebView 提交帖子反对: postID=\(postID), action=\(action), referer=\(referer.absoluteString)")
        do {
            let loader = await MainActor.run {
                HiddenWebViewLoader.shared
            }
            let response = try await loader.submitPostDislike(
                pageURL: referer,
                postID: postID,
                action: action,
                timeoutInterval: timeoutInterval
            )
            await requestLock.release()
            return response
        } catch {
            await requestLock.release()
            throw error
        }
    }
}

enum CommentSubmissionAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;
      let originalFetch = window.fetch;
      const originalXHROpen = window.XMLHttpRequest && window.XMLHttpRequest.prototype.open;
      const originalXHRSend = window.XMLHttpRequest && window.XMLHttpRequest.prototype.send;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        if (originalFetch) window.fetch = originalFetch;
        if (originalXHROpen) window.XMLHttpRequest.prototype.open = originalXHROpen;
        if (originalXHRSend) window.XMLHttpRequest.prototype.send = originalXHRSend;
        resolve(payload);
      };

      try {
        const isCommentRequest = (url) => String(url || "").includes("/api/content/new-comment");

        const parseResponseBody = (statusCode, body) => {
          let message = null;
          try {
            const json = JSON.parse(body || "{}");
            message = json.message || json.error || json.msg || null;
          } catch (_) {}
          finish({
            ok: statusCode >= 200 && statusCode < 300,
            statusCode,
            message,
            reason: statusCode >= 200 && statusCode < 300 ? "submitted" : "server_error",
            body: body || ""
          });
        };

        const visible = (element) => {
          if (!element) return false;
          const style = window.getComputedStyle(element);
          const rect = element.getBoundingClientRect();
          return style.display !== "none" && style.visibility !== "hidden" && rect.width > 0 && rect.height > 0;
        };

        const sleep = (milliseconds) => new Promise((done) => window.setTimeout(done, milliseconds));

        const findEditor = () =>
          document.querySelector(".comment-container textarea[tabindex='2']") ||
          document.querySelector("textarea[tabindex='2']") ||
          document.querySelector(".vditor textarea") ||
          document.querySelector(".vditor [contenteditable='true']") ||
          document.querySelector(".milkdown .editor") ||
          document.querySelector(".milkdown [contenteditable='true']") ||
          document.querySelector(".ProseMirror") ||
          document.querySelector("[contenteditable='true']") ||
          document.querySelector("textarea");

        const findSubmitButton = () => {
          const selectorButton = document.querySelector("button.submit.btn:not(:disabled)");
          const buttons = Array.from(document.querySelectorAll("button, input[type='button'], input[type='submit']"));
          const textButton = buttons.find((button) => {
            const text = (button.innerText || button.textContent || button.value || "").trim();
            return visible(button) && !button.disabled && /发送|提交|评论|回复|发布|submit|send|comment|reply/i.test(text);
          });
          return selectorButton || textButton;
        };

        const waitFor = async (finder, milliseconds) => {
          const deadline = Date.now() + milliseconds;
          while (Date.now() < deadline) {
            const element = finder();
            if (element) return element;
            await sleep(150);
          }
          return finder();
        };

        const editor = await waitFor(findEditor, Math.min(5000, timeoutMs));

        if (!editor) {
          finish({ ok: false, reason: "editor_not_found" });
          return;
        }

        editor.focus();
        editor.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
        editor.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
        editor.click();

        const readText = (target) => {
          if ("value" in target) return target.value || "";
          return target.innerText || target.textContent || "";
        };

        const readRenderedText = (target) => [
          readText(target),
          document.querySelector(".vditor-reset")?.innerText || "",
          document.querySelector(".vditor-ir textarea")?.value || "",
          document.querySelector(".milkdown .editor")?.innerText || "",
          document.querySelector(".ProseMirror")?.innerText || "",
          document.querySelector("[contenteditable='true']")?.innerText || ""
        ].join("\\n");

        const setText = async (target, text) => {
          const assignText = (value) => {
            if ("value" in target) {
              const descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(target), "value");
              if (descriptor && descriptor.set) {
                descriptor.set.call(target, value);
              } else {
                target.value = value;
              }
            } else {
              target.textContent = value;
            }
            target.dispatchEvent(new InputEvent("input", {
              inputType: "insertText",
              data: value,
              bubbles: true,
              cancelable: true
            }));
            target.dispatchEvent(new Event("change", { bubbles: true }));
          };

          assignText("");
          if ("select" in target) {
            target.select();
          }
          document.execCommand("selectAll", false, null);

          if ("value" in target) {
            try {
              target.setSelectionRange(0, target.value.length);
            } catch (_) {}
          }

          try {
            target.dispatchEvent(new InputEvent("beforeinput", {
              inputType: "insertFromPaste",
              data: text,
              bubbles: true,
              cancelable: true
            }));
          } catch (_) {}

          try {
            const dataTransfer = new DataTransfer();
            dataTransfer.setData("text/plain", text);
            target.dispatchEvent(new ClipboardEvent("paste", {
              clipboardData: dataTransfer,
              bubbles: true,
              cancelable: true
            }));
          } catch (_) {}

          await sleep(120);

          if (!readRenderedText(target).includes(text)) {
            assignText(text);
          }

          await sleep(120);

          if (!readRenderedText(target).includes(text)) {
            try {
              if ("select" in target) {
                target.select();
              }
              document.execCommand("selectAll", false, null);
              document.execCommand("insertText", false, text);
              target.dispatchEvent(new InputEvent("input", {
                inputType: "insertText",
                data: text,
                bubbles: true,
                cancelable: true
              }));
            } catch (_) {}
          }

          await sleep(120);

          if (!readRenderedText(target).includes(text)) {
            if ("select" in target) {
              target.select();
            }
            document.execCommand("selectAll", false, null);
            for (const char of text) {
              document.execCommand("insertText", false, char);
              target.dispatchEvent(new InputEvent("input", {
                inputType: "insertText",
                data: char,
                bubbles: true,
                cancelable: true
              }));
              await sleep(8);
            }
          }

          target.dispatchEvent(new KeyboardEvent("keydown", { key: " ", keyCode: 32, bubbles: true }));
          target.dispatchEvent(new KeyboardEvent("keyup", { key: " ", keyCode: 32, bubbles: true }));
        };

        await setText(editor, commentText);

        if (!readRenderedText(editor).includes(commentText)) {
          finish({ ok: false, reason: "fill_failed", body: readRenderedText(editor) });
          return;
        }

        if (originalFetch) {
          window.fetch = function(input, init) {
            const requestURL = typeof input === "string" ? input : (input && input.url);
            const promise = originalFetch.apply(this, arguments);
            if (isCommentRequest(requestURL)) {
              promise
                .then((response) => response.clone().text()
                  .then((body) => parseResponseBody(response.status, body))
                  .catch(() => parseResponseBody(response.status, "")))
                .catch((error) => finish({
                  ok: false,
                  reason: "network_error",
                  message: String(error && error.message ? error.message : error)
                }));
            }
            return promise;
          };
        }

        if (originalXHROpen && originalXHRSend) {
          window.XMLHttpRequest.prototype.open = function(method, url) {
            this.__nodeseekCommentURL = url;
            return originalXHROpen.apply(this, arguments);
          };
          window.XMLHttpRequest.prototype.send = function() {
            if (isCommentRequest(this.__nodeseekCommentURL)) {
              this.addEventListener("loadend", () => {
                parseResponseBody(this.status, this.responseText || "");
              });
              this.addEventListener("error", () => finish({ ok: false, reason: "network_error" }));
            }
            return originalXHRSend.apply(this, arguments);
          };
        }

        const submitButton = await waitFor(findSubmitButton, Math.min(5000, timeoutMs));

        if (!submitButton || !visible(submitButton) || submitButton.disabled) {
          finish({ ok: false, reason: "submit_button_not_found" });
          return;
        }

        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        submitButton.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
        submitButton.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }));
        submitButton.click();
      } catch (error) {
        finish({
          ok: false,
          reason: "javascript_exception",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}

enum PostCollectionAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        resolve(payload);
      };

      const parseJSON = (body) => {
        try {
          return JSON.parse(body || "{}");
        } catch (_) {
          return {};
        }
      };

      try {
        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        const response = await window.fetch("/api/statistics/collection", {
          method: "POST",
          credentials: "include",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            postId: postID,
            action
          })
        });

        const body = await response.text();
        const json = parseJSON(body);
        finish({
          ok: response.status >= 200 && response.status < 300 && json.success !== false,
          statusCode: response.status,
          response: {
            success: typeof json.success === "boolean" ? json.success : null,
            message: json.message || json.msg || json.error || null,
            postCollectionCount: typeof json.postCollectionCount === "number" ? json.postCollectionCount : null,
            userCollectionCount: typeof json.userCollectionCount === "number" ? json.userCollectionCount : null
          },
          reason: response.status >= 200 && response.status < 300 && json.success !== false ? "submitted" : "server_error",
          body
        });
      } catch (error) {
        finish({
          ok: false,
          reason: "network_error",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}

enum CommentUpvoteAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        resolve(payload);
      };

      const parseJSON = (body) => {
        try {
          return JSON.parse(body || "{}");
        } catch (_) {
          return {};
        }
      };

      const readCount = (root) => {
        if (!root) return null;
        const countText = root.querySelector("span")?.textContent || root.textContent || "";
        const matched = String(countText).match(/\\d+/);
        if (!matched) return null;
        return Number(matched[0]);
      };

      const pickUpvoteElement = (commentRoot) => {
        if (!commentRoot) return null;
        const direct = commentRoot.querySelector(".menu-item[title='点赞']");
        if (direct) return direct;
        const candidates = Array.from(commentRoot.querySelectorAll(".menu-item"));
        return candidates.find((node) => {
          const title = String(node.getAttribute("title") || "").trim();
          const text = String(node.textContent || "").trim();
          const className = String(node.className || "");
          const source = `${title} ${text} ${className}`.toLowerCase();
          return /点赞|赞同|upvote|like/.test(source);
        }) || null;
      };

      const locateCommentRoot = (id) => {
        const normalizedID = String(id);
        return document.querySelector(`[data-comment-id='${normalizedID}']`) ||
          document.getElementById(normalizedID) ||
          document.querySelector(`#comment-${normalizedID}`);
      };

      try {
        const commentRoot = locateCommentRoot(commentID);
        const upvoteElement = pickUpvoteElement(commentRoot);
        if (!commentRoot || !upvoteElement) {
          finish({
            ok: false,
            statusCode: 404,
            response: {
              success: false,
              message: "未找到可点赞的评论节点",
              current: null
            },
            reason: "comment_not_found",
            body: ""
          });
          return;
        }

        if (upvoteElement.classList.contains("clicked")) {
          finish({
            ok: false,
            statusCode: 200,
            response: {
              success: false,
              message: "该评论已点赞",
              current: readCount(upvoteElement)
            },
            reason: "already_clicked",
            body: ""
          });
          return;
        }

        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        const response = await window.fetch("/api/statistics/upvote", {
          method: "POST",
          credentials: "include",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            commentId: commentID,
            action
          })
        });

        const body = await response.text();
        const json = parseJSON(body);
        finish({
          ok: response.status >= 200 && response.status < 300 && json.success !== false,
          statusCode: response.status,
          response: {
            success: typeof json.success === "boolean" ? json.success : null,
            message: json.message || json.msg || json.error || null,
            current: typeof json.current === "number" ? json.current : null
          },
          reason: response.status >= 200 && response.status < 300 && json.success !== false ? "submitted" : "server_error",
          body
        });
      } catch (error) {
        finish({
          ok: false,
          reason: "network_error",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}

enum PostUpvoteAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        resolve(payload);
      };

      const parseJSON = (body) => {
        try {
          return JSON.parse(body || "{}");
        } catch (_) {
          return {};
        }
      };

      const readCount = (root) => {
        if (!root) return null;
        const countText = root.querySelector("span")?.textContent || root.textContent || "";
        const matched = String(countText).match(/\\d+/);
        if (!matched) return null;
        return Number(matched[0]);
      };

      const pickPostRoot = () =>
        document.querySelector(".nsk-post > .content-item") ||
        document.querySelector(".post-title + .content-item") ||
        document.querySelector("#nsk-body-left .content-item");

      const readPostCommentID = (postRoot) => {
        const rawID = postRoot?.getAttribute("data-comment-id") || "";
        const commentID = Number(rawID);
        return Number.isInteger(commentID) && commentID > 0 ? commentID : null;
      };

      const pickPostUpvoteElement = () => {
        const postRoot = pickPostRoot();
        const candidates = Array.from((postRoot || document).querySelectorAll(".menu-item[title='点赞'], .menu-item"));
        return candidates.find((node) => {
          if (!postRoot && node.closest(".comment-container, ul.comments")) return false;
          const title = String(node.getAttribute("title") || "").trim();
          const text = String(node.textContent || "").trim();
          const className = String(node.className || "");
          const source = `${title} ${text} ${className}`.toLowerCase();
          return /点赞|赞同|upvote|like/.test(source);
        }) || null;
      };

      try {
        const postRoot = pickPostRoot();
        const commentID = readPostCommentID(postRoot);
        if (!commentID) {
          finish({
            ok: false,
            statusCode: 404,
            response: {
              success: false,
              message: "未找到帖子正文的评论 ID",
              current: null
            },
            reason: "post_comment_id_not_found",
            body: ""
          });
          return;
        }

        const upvoteElement = pickPostUpvoteElement();
        if (upvoteElement && upvoteElement.classList.contains("clicked")) {
          finish({
            ok: false,
            statusCode: 200,
            response: {
              success: false,
              message: "该帖子已点赞",
              current: readCount(upvoteElement)
            },
            reason: "already_clicked",
            body: ""
          });
          return;
        }

        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        const response = await window.fetch("/api/statistics/upvote", {
          method: "POST",
          credentials: "include",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            commentId: commentID,
            action
          })
        });

        const body = await response.text();
        const json = parseJSON(body);
        finish({
          ok: response.status >= 200 && response.status < 300 && json.success !== false,
          statusCode: response.status,
          response: {
            success: typeof json.success === "boolean" ? json.success : null,
            message: json.message || json.msg || json.error || null,
            current: typeof json.current === "number" ? json.current : null
          },
          reason: response.status >= 200 && response.status < 300 && json.success !== false ? "submitted" : "server_error",
          body
        });
      } catch (error) {
        finish({
          ok: false,
          reason: "network_error",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}

enum CommentDislikeAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        resolve(payload);
      };

      const parseJSON = (body) => {
        try {
          return JSON.parse(body || "{}");
        } catch (_) {
          return {};
        }
      };

      const readCount = (root) => {
        if (!root) return null;
        const countText = root.querySelector("span")?.textContent || root.textContent || "";
        const matched = String(countText).match(/\\d+/);
        if (!matched) return null;
        return Number(matched[0]);
      };

      const pickDislikeElement = (commentRoot) => {
        if (!commentRoot) return null;
        const direct = commentRoot.querySelector(".menu-item[title='反对']");
        if (direct) return direct;
        const candidates = Array.from(commentRoot.querySelectorAll(".menu-item"));
        return candidates.find((node) => {
          const title = String(node.getAttribute("title") || "").trim();
          const text = String(node.textContent || "").trim();
          const className = String(node.className || "");
          const source = `${title} ${text} ${className}`.toLowerCase();
          return /反对|点踩|dislike|downvote|oppose/.test(source);
        }) || null;
      };

      const locateCommentRoot = (id) => {
        const normalizedID = String(id);
        return document.querySelector(`[data-comment-id='${normalizedID}']`) ||
          document.getElementById(normalizedID) ||
          document.querySelector(`#comment-${normalizedID}`);
      };

      try {
        const commentRoot = locateCommentRoot(commentID);
        const dislikeElement = pickDislikeElement(commentRoot);
        if (!commentRoot || !dislikeElement) {
          finish({
            ok: false,
            statusCode: 404,
            response: {
              success: false,
              message: "未找到可反对的评论节点",
              current: null
            },
            reason: "comment_not_found",
            body: ""
          });
          return;
        }

        if (dislikeElement.classList.contains("clicked")) {
          finish({
            ok: false,
            statusCode: 200,
            response: {
              success: false,
              message: "该评论已反对",
              current: readCount(dislikeElement)
            },
            reason: "already_clicked",
            body: ""
          });
          return;
        }

        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        const response = await window.fetch("/api/statistics/dislike", {
          method: "POST",
          credentials: "include",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            commentId: commentID,
            action
          })
        });

        const body = await response.text();
        const json = parseJSON(body);
        finish({
          ok: response.status >= 200 && response.status < 300 && json.success !== false,
          statusCode: response.status,
          response: {
            success: typeof json.success === "boolean" ? json.success : null,
            message: json.message || json.msg || json.error || null,
            current: typeof json.current === "number" ? json.current : null
          },
          reason: response.status >= 200 && response.status < 300 && json.success !== false ? "submitted" : "server_error",
          body
        });
      } catch (error) {
        finish({
          ok: false,
          reason: "network_error",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}

enum PostDislikeAutomationScript {
    static let source = """
    return await new Promise(async (resolve) => {
      let resolved = false;
      let timer = null;

      const finish = (payload) => {
        if (resolved) return;
        resolved = true;
        if (timer) window.clearTimeout(timer);
        resolve(payload);
      };

      const parseJSON = (body) => {
        try {
          return JSON.parse(body || "{}");
        } catch (_) {
          return {};
        }
      };

      const readCount = (root) => {
        if (!root) return null;
        const countText = root.querySelector("span")?.textContent || root.textContent || "";
        const matched = String(countText).match(/\\d+/);
        if (!matched) return null;
        return Number(matched[0]);
      };

      const pickPostRoot = () =>
        document.querySelector(".nsk-post > .content-item") ||
        document.querySelector(".post-title + .content-item") ||
        document.querySelector("#nsk-body-left .content-item");

      const readPostCommentID = (postRoot) => {
        const rawID = postRoot?.getAttribute("data-comment-id") || "";
        const commentID = Number(rawID);
        return Number.isInteger(commentID) && commentID > 0 ? commentID : null;
      };

      const pickPostDislikeElement = () => {
        const postRoot = pickPostRoot();
        const candidates = Array.from((postRoot || document).querySelectorAll(".menu-item[title='反对'], .menu-item"));
        return candidates.find((node) => {
          if (!postRoot && node.closest(".comment-container, ul.comments")) return false;
          const title = String(node.getAttribute("title") || "").trim();
          const text = String(node.textContent || "").trim();
          const className = String(node.className || "");
          const source = `${title} ${text} ${className}`.toLowerCase();
          return /反对|点踩|dislike|downvote|oppose/.test(source);
        }) || null;
      };

      try {
        const postRoot = pickPostRoot();
        const commentID = readPostCommentID(postRoot);
        if (!commentID) {
          finish({
            ok: false,
            statusCode: 404,
            response: {
              success: false,
              message: "未找到帖子正文的评论 ID",
              current: null
            },
            reason: "post_comment_id_not_found",
            body: ""
          });
          return;
        }

        const dislikeElement = pickPostDislikeElement();
        if (dislikeElement && dislikeElement.classList.contains("clicked")) {
          finish({
            ok: false,
            statusCode: 200,
            response: {
              success: false,
              message: "该帖子已反对",
              current: readCount(dislikeElement)
            },
            reason: "already_clicked",
            body: ""
          });
          return;
        }

        timer = window.setTimeout(() => {
          finish({ ok: false, reason: "submit_timeout" });
        }, timeoutMs);

        const response = await window.fetch("/api/statistics/dislike", {
          method: "POST",
          credentials: "include",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            commentId: commentID,
            action
          })
        });

        const body = await response.text();
        const json = parseJSON(body);
        finish({
          ok: response.status >= 200 && response.status < 300 && json.success !== false,
          statusCode: response.status,
          response: {
            success: typeof json.success === "boolean" ? json.success : null,
            message: json.message || json.msg || json.error || null,
            current: typeof json.current === "number" ? json.current : null
          },
          reason: response.status >= 200 && response.status < 300 && json.success !== false ? "submitted" : "server_error",
          body
        });
      } catch (error) {
        finish({
          ok: false,
          reason: "network_error",
          message: String(error && error.message ? error.message : error)
        });
      }
    });
    """
}
