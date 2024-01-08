/// <reference path="hljs.d.ts"/>
/// <reference path="showdown.d.ts"/>

interface Post {
    created_time?: number,
    modified_time?: number,
    title?: string,
    views?: number,
    author?: string,
    content?: string,
    published?: number,
    cover_url?: string,
    id: number,
}


function timeConverter(UNIX_timestamp: number): string {
    var a = new Date(UNIX_timestamp * 1000);
    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    var year = a.getFullYear();
    var month = months[a.getMonth()];
    var date = a.getDate();
    var hour = a.getHours();
    var min = a.getMinutes();
    var sec = a.getSeconds();
    var time = date + ' ' + month + ' ' + year + ' ' + hour + ':' + min + ':' + sec ;
    return time;
}

let listArticle = async (admin: boolean) => {
    let article_cont = document.getElementById("articles-container")!
    article_cont.style.justifyContent = 'start'
    article_cont.innerHTML = ''

    let menu = getMenu()
    menu.style.display = 'none'
    
    let editing_title = false
    let editing_cover = false

    let post_meta: [Post] = await fetch("/post").then((res) => res.json())
    let appendArticle = (post: Post) => {
        console.log(post.cover_url)
        const s = `        
        <a class="article-col" href="article/${post.id}">
            <h2 class="article-cover" article_id="${post.id}" id="article_${post.id}">
                <div class="article-desc">
                    ${post.title}
                </div>
            </h2>
        </a>`
        let article_col = DOMFromStr(s) as HTMLElement
        if (post.id < 0) {
            article_col.style.opacity  = '0'
        } else if (admin) {
            article_col.addEventListener('contextmenu', (ev: MouseEvent) => {
                ev.preventDefault()
                menu.style.top = `${ev.pageY}px`
                menu.style.left = `${ev.pageX}px`
                menu.style.display = ''
                let old_id = menu.getAttribute('article_id') || -1
                let new_id = (ev.target! as HTMLElement).getAttribute('article_id')!
                menu.setAttribute('article_id', new_id)
                let orignal_txt = ["Delete", "Edit Title", "Edit Cover"]
                if (old_id !== new_id) {
                    for(var i=0, len = menu.childElementCount ; i < len; ++i){
                        menu.children[i].innerHTML = orignal_txt[i]
                    }
                    editing_cover = false
                    editing_title = false
                }


            }, false);
        }
        article_col.addEventListener('click', route)
        article_cont.appendChild(article_col)
        const background_el = article_col.firstElementChild! as HTMLElement;
        if (post.cover_url) {
            background_el.style.backgroundImage = Url2Css(post.cover_url!)
        } else {
            background_el.style.background = `crimson`
        }
    }
    post_meta.forEach(appendArticle);
    if (!admin) return;
    // auxiliary "article" for adding new article

    let add = DOMFromStr('<a class="article-col add" id="add">+</a>')
    add.addEventListener('click', async (ev) => {
        ev.preventDefault()
        let response = await fetch("/post", {
            method: 'POST',
            body: JSON.stringify({
                title: "new title",
                content: "Edit Me",
                author: "cat",
                published: 0,
                cover_url: "",
            })
        })
        let id = (await response.json()).id
        let response2 = await fetch(`post/${id}`, {
            method: 'PATCH'
        })
        if (response2.status == 200) {
            let new_meta = await response2.json()
            console.log(new_meta)
            let add = article_cont.lastChild!
            appendArticle(new_meta)
            article_cont.append(add)
        }
    })
    article_cont.appendChild(add)
    article_cont.onclick = () => menu.style.display = 'none'
    // context menu for editing article
    let addMenuItem = (id: string, callback: (article_id: string, target: HTMLElement) => void) => {
        let el = document.getElementById(id)!
        el.addEventListener('click', async (ev) => {
            ev.preventDefault()
            ev.stopPropagation()
            console.log("one of the menu item is clicked")
            let article_id = menu.getAttribute('article_id')!
            callback(article_id, el)
        })
    }
    addMenuItem('delete', async (id, target) => {
        let response = await fetch(`/post/${id}`, {
            method: 'DELETE',
        })
        if (response.status == 200) {
            console.log("deleteing")
            article_cont.removeChild(getArticleOut(id))
            menu.style.display = 'none'
        }
    })


    addMenuItem('edit-title', async (id, target) => {
        if (editing_title) return
        editing_title = true
        let article_title_el = getArticleTitle(id);
        let inp = document.createElement('input')
        inp.type = 'text'
        inp.className = 'edit-input'
        inp.value = article_title_el.innerText
        target.innerHTML = ''
        target.appendChild(inp)

        // commit on enter
        inp.onkeydown = async (ev2) => {
            var keyCode = ev2.key
            if (keyCode == 'Enter'){
                let response = await fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        title: inp.value
                    })
                })
                if (response.status === 200) {
                    article_title_el.innerText = inp.value
                    target.innerHTML = 'Edit Title'
                    editing_title = false
                }

            }
        }
    })
    addMenuItem('edit-cover', async (id, target) => {
        if (editing_cover) return
        editing_cover = true
        let article_bg_el = getArticleCover(id)
        let inp = document.createElement('input')
        inp.type = 'text'
        inp.className = 'edit-input'
        inp.value = Css2Url(article_bg_el.style.backgroundImage) 
        target.innerHTML = ''
        target.appendChild(inp)

        inp.onkeydown = async (ev2) => {
            var keyCode = ev2.key
            if (keyCode == 'Enter'){
                let response = await fetch(`/post/${id}`, {
                    method: 'PUT',
                    body: JSON.stringify({
                        cover_url: inp.value
                    })
                })
                if (response.status === 200) {
                    article_bg_el.style.backgroundImage = Url2Css(inp.value)
                    target.innerHTML = 'Edit Cover'
                    editing_cover = false
                }
            }
        }
    })
}

let Url2Css = (u: string) => {
    return `url("${u}")`
}

let Css2Url = (c: string) => {
    return c.substring(5, c.length - 2)
}

let indexScroll = (ev) => {
    let index = getArticleIndex()
    let article_cont = getArticlesContainer()
    if (index === null) return;
    let pad_str = window.getComputedStyle(article_cont, null).getPropertyValue('padding-top')
    let pad = parseFloat(pad_str.slice(0, pad_str.length - 2))
    // console.log(document.documentElement.scrollTop, article_cont.offsetTop)

    if (document.documentElement.scrollTop < article_cont.offsetTop) {
        index.style.top = `${article_cont.offsetTop - document.documentElement.scrollTop + pad}px`
    } else {
        index.style.top = pad_str
    }
}

let convertMarkdown = (content) => {
    var converter = new showdown.Converter()
    let html = converter.makeHtml(content)
    let tmp = document.createElement('div')
    tmp.innerHTML = html.trim()
    let codes = tmp.getElementsByTagName('code')
    console.log(codes)
    return tmp.innerHTML
}
let generateIndex = () => {
    let index = document.getElementById("article-index")!
    let article_content = document.getElementById('article-content')!
    let title = document.getElementById('article-title')!

    index.innerHTML = ''
    let title_clone = document.createElement('a')!
    title_clone.innerHTML = title.innerHTML
    title_clone.href = `#article-title`
    index.appendChild(title_clone)
    
    let h3s = article_content.getElementsByTagName('H3')
    for (let h3 of h3s) {
        h3.id = "__article_index_" + h3.innerHTML;
        let a = document.createElement('a')
        a.innerHTML = h3.innerHTML
        a.href = `#${h3.id}`
        index.appendChild(a)
    }
}

let preview = true
let article_id = -1
let dirty = false

let loadArticle = async (id: string | number, callback?: (post: Post, id: string | number) => void) => {
    getMenu().style.display = 'none'
    let article = await (await fetch(`/post/${id}`)).text()
    console.log(article)
    let res: Post = JSON.parse(article)
    let article_cont = document.getElementById("articles-container")!
    article_cont.style.justifyContent = 'center'
    article_cont.style.flexDirection = 'column'
    article_cont.style.alignItems = 'center'
    window.scroll(5, 0)


    window.onscroll = () => {
        indexScroll(null)
    }
    indexScroll(null)
    callback!(res, id)


    window.scrollTo(0, article_cont.offsetTop)
}




let getArticleCover = (id: string) => {
    return document.getElementById(`article_${id}`)!
}
let getArticleOut = (id: string) => {
    return getArticleCover(id).parentElement!
}
let getArticleTitle = (id: string) => {
    return getArticleCover(id).firstElementChild! as HTMLElement
}

let getArticleIndex = () => {
    return document.getElementById('article-index')!
}

let getArticlesContainer = () => {
    return document.getElementById("articles-container")!
}

let getMenu = () => {
    return document.getElementById('menu')!
}

function getTargetA(ev) {
    return ev.target.tagName == 'H2' ? ev.target.parentElement : ev.target.parentElement.parentElement
}

function DOMFromStr(s) {
    let d = document.createElement("div")
    d.innerHTML = s.trim()
    return d.firstChild!
}




