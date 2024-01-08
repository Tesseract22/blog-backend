/// <reference path="common.ts"/>
let editArticle = (ev) => {
    ev.stopPropagation()
    preview = !preview
    let text = document.getElementById('text')!
    let index = document.getElementById('article-index')!
    if (preview) {
        index.style.display = ''
        content = (text.firstElementChild! as HTMLInputElement).value
        text.innerHTML = convertMarkdown(content)
        hljs.highlightAll()
        generateIndex()
    } else {
        dirty = true
        document.getElementById('save')!.innerText = 'Save'
        index.style.display = 'none'
        let input = DOMFromStr('<textarea type="text" id="editor"></textarea>') as HTMLTextAreaElement
        input.value = content
        text.innerHTML = ''
        text.appendChild(input)
    }


}
const base = "/admin"
const route = (event) => {
    // console.log(event.target)
    
    let href = getTargetA(event).getAttribute('href')
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", base + "/" + href);
    handleLocation()

};

// const routes = {
//     404: "/pages/404.html",
//     "/": "/pages/index.html",
//     "/about": "/pages/about.html",
//     "/lorem": "/pages/lorem.html",
// };
let content = ""

const handleLocation = async () => {
    const path_ = window.location.pathname;
    const path = path_.slice(base.length, path_.length)

    if (path.length === 0) {
        dirty = false
        return await listArticle(true)
    }
    let match = (/^\/article\/(\d+)$/.exec(path) || [-1,-1])
    let article_id = match[1] as number
    let jump_id = window.location.hash
    console.log(jump_id)
    if (article_id > 0) {
        if (jump_id !== "" && dirty) {
            scrollTo(0, document.getElementById(jump_id)!.offsetTop)
        } else {
            return loadArticle(article_id, (res: Post, id: string | number) => {
                console.log("loadArticle callback")
                content = res.content!
                let article_cont = getArticlesContainer()
                let s =         
                `        
                <label class="switch">
                    <input type="checkbox">
                    <span class="slider"  id="edit-switch"></span>
                </label>
                <button id='save'>Save</button>
                <div id="article-index"></div>
                <div id="article-content">
                    <h1 id="article-title">${res.title}</h1>
                    <div>views: ${res.views}</div>
                    <div>created: ${timeConverter(res.created_time!)}, last modified: ${timeConverter(res.modified_time!)}</div>
                    <br></br>
                    <div id="text">
                    ${convertMarkdown(content)}
                    </div>
                </div>`
            
                article_cont.innerHTML = s.trim()
                hljs.highlightAll()
                generateIndex()
            
                let sw = document.getElementById('edit-switch')!
                sw.onclick = editArticle
                let save = document.getElementById('save')!
                save.onclick = async (ev) => {
                    let response = await fetch(`/post/${id}`, {
                        method: "PUT",
                        body: JSON.stringify({
                            content: content
                        })
                    })
                    if (response.status !== 200) {
                        console.warn("Cannot Save")
                    } else {
                        save.innerText = "Saved!"
                    }
                }
            })
        }
    }
}

window.onpopstate = handleLocation;
// window.onload = async () => {
//     listArticle()
// }
window.onload = () => handleLocation();



