// The Vue build version to load with the `import` command
// (runtime-only or standalone) has been set in webpack.base.conf with an alias.
import Vue from 'vue'

import ElementUI from 'element-ui'
import 'element-ui/lib/theme-chalk/index.css'

Vue.config.productionTip = false

Vue.use(ElementUI)

const HxPay = window.require('hxpay')
const hxPay = new HxPay()
const dummyPubKey = 'HX8mT7XvtTARjdZQ9bqHRoJRMf7P7azFqTQACckaVenM2GmJyxLh'
var time = null;  //  在这里定义time 为null
/**
* UTF16和UTF8转换对照表
* U+00000000 – U+0000007F   0xxxxxxx
* U+00000080 – U+000007FF   110xxxxx 10xxxxxx
* U+00000800 – U+0000FFFF   1110xxxx 10xxxxxx 10xxxxxx
* U+00010000 – U+001FFFFF   11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
* U+00200000 – U+03FFFFFF   111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
* U+04000000 – U+7FFFFFFF   1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
*/
var Base64 = {
  // 转码表
  table: [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
    'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
    'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', '+', '/'
  ],
  UTF16ToUTF8: function(str) {
    var res = [], len = str.length;
    for (var i = 0; i < len; i++) {
      var code = str.charCodeAt(i);
      if (code > 0x0000 && code <= 0x007F) {
        // 单字节，这里并不考虑0x0000，因为它是空字节
        // U+00000000 – U+0000007F   0xxxxxxx
        res.push(str.charAt(i));
      } else if (code >= 0x0080 && code <= 0x07FF) {
        // 双字节
        // U+00000080 – U+000007FF   110xxxxx 10xxxxxx
        // 110xxxxx
        var byte1 = 0xC0 | ((code >> 6) & 0x1F);
        // 10xxxxxx
        var byte2 = 0x80 | (code & 0x3F);
        res.push(
          String.fromCharCode(byte1),
          String.fromCharCode(byte2)
        );
      } else if (code >= 0x0800 && code <= 0xFFFF) {
        // 三字节
        // U+00000800 – U+0000FFFF   1110xxxx 10xxxxxx 10xxxxxx
        // 1110xxxx
        var byte1 = 0xE0 | ((code >> 12) & 0x0F);
        // 10xxxxxx
        var byte2 = 0x80 | ((code >> 6) & 0x3F);
        // 10xxxxxx
        var byte3 = 0x80 | (code & 0x3F);
        res.push(
          String.fromCharCode(byte1),
          String.fromCharCode(byte2),
          String.fromCharCode(byte3)
        );
      } else if (code >= 0x00010000 && code <= 0x001FFFFF) {
        // 四字节
        // U+00010000 – U+001FFFFF   11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
      } else if (code >= 0x00200000 && code <= 0x03FFFFFF) {
        // 五字节
        // U+00200000 – U+03FFFFFF   111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      } else /** if (code >= 0x04000000 && code <= 0x7FFFFFFF)*/ {
        // 六字节
        // U+04000000 – U+7FFFFFFF   1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      }
    }

    return res.join('');
  },
  UTF8ToUTF16: function(str) {
    var res = [], len = str.length;
    var i = 0;
    for (var i = 0; i < len; i++) {
      var code = str.charCodeAt(i);
      // 对第一个字节进行判断
      if (((code >> 7) & 0xFF) == 0x0) {
        // 单字节
        // 0xxxxxxx
        res.push(str.charAt(i));
      } else if (((code >> 5) & 0xFF) == 0x6) {
        // 双字节
        // 110xxxxx 10xxxxxx
        var code2 = str.charCodeAt(++i);
        var byte1 = (code & 0x1F) << 6;
        var byte2 = code2 & 0x3F;
        var utf16 = byte1 | byte2;
        res.push(Sting.fromCharCode(utf16));
      } else if (((code >> 4) & 0xFF) == 0xE) {
        // 三字节
        // 1110xxxx 10xxxxxx 10xxxxxx
        var code2 = str.charCodeAt(++i);
        var code3 = str.charCodeAt(++i);
        var byte1 = (code << 4) | ((code2 >> 2) & 0x0F);
        var byte2 = ((code2 & 0x03) << 6) | (code3 & 0x3F);
        var utf16 = ((byte1 & 0x00FF) << 8) | byte2
        res.push(String.fromCharCode(utf16));
      } else if (((code >> 3) & 0xFF) == 0x1E) {
        // 四字节
        // 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
      } else if (((code >> 2) & 0xFF) == 0x3E) {
        // 五字节
        // 111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      } else /** if (((code >> 1) & 0xFF) == 0x7E)*/ {
        // 六字节
        // 1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
      }
    }
    return res.join('');
  },
  encode: function(str) {
    if (!str) {
      return '';
    }
    var utf8 = Base64.UTF16ToUTF8(str); // 转成UTF8
    var i = 0; // 遍历索引
    var len = utf8.length;
    var res = [];
    while (i < len) {
      var c1 = utf8.charCodeAt(i++) & 0xFF;
      res.push(Base64.table[c1 >> 2]);
      // 需要补2个=
      if (i == len) {
        res.push(Base64.table[(c1 & 0x3) << 4]);
        res.push('==');
        break;
      }
      var c2 = utf8.charCodeAt(i++);
      // 需要补1个=
      if (i == len) {
        res.push(Base64.table[((c1 & 0x3) << 4) | ((c2 >> 4) & 0x0F)]);
        res.push(Base64.table[(c2 & 0x0F) << 2]);
        res.push('=');
        break;
      }
      var c3 = utf8.charCodeAt(i++);
      res.push(Base64.table[((c1 & 0x3) << 4) | ((c2 >> 4) & 0x0F)]);
      res.push(Base64.table[((c2 & 0x0F) << 2) | ((c3 & 0xC0) >> 6)]);
      res.push(Base64.table[c3 & 0x3F]);
    }

    return res.join('');
  },
  decode: function(str) {
    if (!str) {
      return '';
    }

    var len = str.length;
    var i = 0;
    var res = [];

    while (i < len) {
      var code1 = Base64.table.indexOf(str.charAt(i++));
      var code2 = Base64.table.indexOf(str.charAt(i++));
      var code3 = Base64.table.indexOf(str.charAt(i++));
      var code4 = Base64.table.indexOf(str.charAt(i++));

      var c1 = (code1 << 2) | (code2 >> 4);
      var c2 = ((code2 & 0xF) << 4) | (code3 >> 2);
      var c3 = ((code3 & 0x3) << 6) | code4;

      res.push(String.fromCharCode(c1));

      if (code3 != 64) {
        res.push(String.fromCharCode(c2));
      }
      if (code4 != 64) {
        res.push(String.fromCharCode(c3));
      }

    }

    return Base64.UTF8ToUTF16(res.join(''));
  }
}


/* eslint-disable no-new */
new Vue({
  el: '#app',
  data: {
    hxConfig: null,
    apisInstance: null,
    nodeClient: null,

    contractAddress: 'HXCJqxXCUbifQRovt9eAj6W8MdmNbjQZfMLf',
    contractCreator: 'HXNTKVdTf7QU1Jutow6LdYtTPJ5X4FP4Sz9q',
    myAddress: null,
    myPubKey: null,
    myHxBalance: 0,
    myContractHxBalance: 0,
    myRoundBet: 0,
    myRoundPrize: 0,

    bonusPoolBalance: 0,
    contractUserCount: 0,
    roundIndex: 0,
    roundParticipationCount: 0,
    roundChessCount: 0,

    lastSerialNumber: null,
    lastResponse: null,
    lastTxid: null,

    chess: {},
    context: {},
    chessBoard: [], // 记录是否走过
    color: 0,
    mul: 19, // 棋盘大小
    boardWidth: 18, // 棋盘宽度
    isEnabled: false,
    isShow: true,
    dialogVisible: true,
    winColorInfo: null,
    textareaInfo: '',
    messageInput: ''
  },
  mounted() {
    hxPay.getConfig()
      .then((config) => {
        console.log('config', config)
        if (!config) {
          this.showError('please install hx extension wallet first')
          return
        }

        // config.network = 'ws://localhost:8090'
        this.hxConfig = config
        window.hx_js.ChainConfig.setChainId(config.chainId)
        this.apisInstance = window.hx_js.Apis.instance(config.network, true)
        this.nodeClient = new window.hx_js.NodeClient(this.apisInstance)
        this.refreshUserInfo()
        this.refreshContractInfo()
        this.drawChessesBoardRepeat()
        this.showGameStatus()
        this.showChatMsg()
        this.getBetPrice()

        hxPay.getUserAddress()
          .then(({ address, pubKey, pubKeyString }) => {
            console.log('address', address)
            console.log('pubKey', pubKey)
            console.log('pubKeyStr', pubKeyString)
            this.myAddress = address
            this.myPubKey = pubKey
            this.refreshUserInfo()
            this.refreshContractInfo()
            this.drawChessesBoardRepeat()
            this.showGameStatus()
            this.showChatMsg()
            this.getBetPrice()
          }, (err) => {
            this.showError(err)
          })
      }, (err) => {
        console.log('get config error', err)
        this.showError(err)
        const config = hxPay.defaultConfig

        this.hxConfig = config
        window.hx_js.ChainConfig.setChainId(config.chainId)
        this.apisInstance = window.hx_js.Apis.instance(config.network, true)
        this.nodeClient = new window.hx_js.NodeClient(this.apisInstance)
        this.refreshUserInfo()
        this.refreshContractInfo()
        this.drawChessesBoardRepeat()
        this.showGameStatus()
        this.showChatMsg()
        this.getBetPrice()
      }),
      setTimeout(() => {
        setInterval(this.showGameStatus, 1000);
        setInterval(this.showChatMsg, 5000);
      }, 1000);

    setTimeout(_ => {
      this.init()
    })
  },
  methods: {
    // 初始化
    init() {
      this.chess = this.$refs.canvas
      this.context = this.chess.getContext('2d')
      this.drawChessBoard()
      this.fillArray()
    },
    fillArray() {
      // 是否走过
      for (let i = 0; i < this.mul; i++) {
        this.chessBoard[i] = []
        for (let j = 0; j < this.mul; j++) {
          this.chessBoard[i][j] = 0
        }
      }
    },
    // 绘制棋盘
    drawChessBoard() {
      const { context } = this
      context.strokeStyle = '#bfbfbf'
      for (let i = 0; i < this.mul; i++) {
        context.moveTo(this.boardWidth + i * this.boardWidth * 2, this.boardWidth)
        context.lineTo(this.boardWidth + i * this.boardWidth * 2, this.boardWidth * (this.mul * 2 - 1))
        context.stroke()
        context.moveTo(this.boardWidth, this.boardWidth + i * this.boardWidth * 2)
        context.lineTo(this.boardWidth * (this.mul * 2 - 1), this.boardWidth + i * this.boardWidth * 2)
        context.stroke()
      }
    },
    showGameStatus() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getContractState',
            ''
          ).then(result => {
            if (result === 'Round_Not_Start') {
              statusDiv.innerHTML = "游戏状态:" + "本轮游戏未开始"
              this.refreshUserInfo()
              this.refreshContractInfo()
              this.drawChessesBoardRepeat()
              this.isEnabled = true
            } else if (result === 'Round_Started') {
              statusDiv.innerHTML = "游戏状态:" + "本轮游戏已开始"
              this.isEnabled = false
            } else if (result === 'Round_Finished') {
              statusDiv.innerHTML = "游戏状态:" + "本轮游戏已结束"
              this.refreshRoundPrize()
              this.refreshRoundWinColor()
              this.isEnabled = true
            } else if (result === 'Invalid_State') {
              statusDiv.innerHTML = "游戏状态:" + "未知"
            }
          }).catch(this.showError)
        }).catch(this.showError)
    },
    showChatMsg() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getChatMsgIndex',
            ''
          ).then(result => {
            if (result) {
              if (parseInt(result) < 50) {
                var args = '1,' + result
              } else {
                args = toString(parseInt(result) - 50) + ',' + result
              }
              this.nodeClient.invokeContractOffline(
                this.myPubKey || dummyPubKey,
                this.contractAddress,
                'getChatMsgByIndex',
                args
              ).then(result => {
                if (result) {
                  result = JSON.parse(result)
                  this.textareaInfo = ''
                  for (let onemsg of result) {
                    onemsg = JSON.parse(onemsg)
                    let addr = onemsg.msgSender
                    let msg = Base64.decode(onemsg.msgContent)
                    let showaddr = addr.substring(0, 3) + '***' + addr.substring(addr.length - 4)
                    this.textareaInfo += showaddr + ':' + msg + '\r'
                  }
                }
              }).catch(this.showError)
            }
          }).catch(this.showError)
        }).catch(this.showError)
    },
    //查询本轮奖金
    refreshRoundPrize() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getRoundBonusBalance',
            this.myAddress
          ).then(result => {
            this.myRoundPrize = result / 100000
          }).catch(this.showError)
        }).catch(this.showError)
    },
    //查询是否可以下棋子
    isAllowPlay() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'isAllowPlay',
            ''
          ).then(result => {
            return result
          }).catch(this.showError)
        }).catch(this.showError)
    },
    //查询每次下注金额
    getBetPrice() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getBetPrice',
            ''
          ).then(result => {
            this.betPrice = parseFloat(result)
          }).catch(this.showError)
        }).catch(this.showError)
    },
    //查询获胜颜色
    refreshRoundWinColor() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getRoundWinColor',
            ''
          ).then(result => {
            if (result === '1') {
              this.winColorInfo = "本轮获胜颜色:黑色"
            } else if (result === '2') {
              this.winColorInfo = "本轮获胜颜色:紫色"
            } else if (result === '3') {
              this.winColorInfo = "本轮获胜颜色:蓝色"
            } else if (result === '4') {
              this.winColorInfo = "本轮获胜颜色:红色"
            } else if (result === '5') {
              this.winColorInfo = "本轮获胜颜色:黄色"
            } else {
              this.winColorInfo = ""
            }
          }).catch(this.showError)
        }).catch(this.showError)
    },
    // 落子实现，画棋子
    onStep(x, y, color) {
      const { context } = this
      context.beginPath()
      context.arc(this.boardWidth + x * this.boardWidth * 2, this.boardWidth + y * this.boardWidth * 2, this.boardWidth - 2, 0, 2 * Math.PI)
      context.closePath()
      const gradient = context.createRadialGradient(15 + x * 30 + 2, 15 + y * 30 - 2, 13, 15 + x * 30 + 2, 15 + y * 30 - 2, 0)
      if (color === 1) {
        gradient.addColorStop(0, 'black')
        gradient.addColorStop(1, 'black')
      } else if (color === 2) {
        gradient.addColorStop(0, 'purple')
        gradient.addColorStop(1, 'purple')
      } else if (color === 3) {
        gradient.addColorStop(0, 'blue')
        gradient.addColorStop(1, 'blue')
      } else if (color === 4) {
        gradient.addColorStop(0, 'red')
        gradient.addColorStop(1, 'red')
      } else {
        gradient.addColorStop(0, 'yellow')
        gradient.addColorStop(1, 'yellow')
      }

      context.fillStyle = gradient
      context.fill()
    },
    // 我方落子
    chessClick(e) {
      // this.initHX()
      clearTimeout(time);  //清除
      const ox = e.offsetX
      const oy = e.offsetY
      const x = Math.floor(ox / this.boardWidth / 2)
      const y = Math.floor(oy / this.boardWidth / 2)

      if (this.myContractHxBalance <= this.betPrice) {
        alert('我的合约余额不足 请充值')
        return
      }

      if (this.chessBoard[x][y] === 0) {
        if (this.isAllowPlay() === false) {
          alert('请稍等')
          return
        }
        this.playChess(x, y)
        //先查询出所有已经下了棋子信息，然后重新画出棋子
        this.drawChessesBoardRepeat()
        // this.chessBoard[x][y] = 1
      }
    },

    //先查询出所有已经下了棋子信息，然后重新画出棋子
    drawChessesBoardRepeat() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getChessInfoCount',
            ''
          ).then(result => {
            console.log('drawChessesBoardRepeat invokeContractOffline getChessInfoUserCount result: ', result)
            this.nodeClient.invokeContractOffline(
              this.myPubKey || dummyPubKey,
              this.contractAddress,
              'getChessInfoByIndex',
              '1,' + result
            ).then(result => {
              result = JSON.parse(result)
              this.myRoundBet = 0
              for (let onechess of result) {
                let addr = null
                for (let k in onechess) {
                  let v = onechess[k]
                  v = JSON.parse(v)
                  let x = parseInt(k / 1000) - 1
                  let y = k % 1000 - 1
                  this.onStep(x, y, v.chessColor)
                  this.chessBoard[x][y] = 1
                  addr = v.chessPlayer
                }
                if (addr === this.myAddress) {
                  // this.myRoundBet += this.betPrice
                  this.myRoundBet = this.FloatAdd(this.myRoundBet, this.betPrice)
                }
              };
            }).catch(this.showError)
          }).catch(this.showError)
        })
        .catch(this.showError)
    },

    mousedown(e) {
      console.log('点击弹起')
      clearTimeout(time);  //首先清除计时器
      time = setTimeout(() => {
        let infoDiv = document.getElementById('infoDiv');
        const ox = e.offsetX
        const oy = e.offsetY
        const x = Math.floor(ox / this.boardWidth / 2)
        const y = Math.floor(oy / this.boardWidth / 2)
        this.nodeClient.afterInited()
          .then(() => {
            this.nodeClient.invokeContractOffline(
              this.myPubKey || dummyPubKey,
              this.contractAddress,
              'getChessInfo',
              parseInt((x + 1) * 1000 + (y + 1))
            ).then(result => {
              if (result) {
                console.log('chessinfo result: ', result)
                // 此处记录鼠标停留在组件上的时候的位置, 可以自己通过加减常量来控制离鼠标的距离.
                // infoDiv.strokeText("Big smile!",e.offsetX,e.offsetY);
                infoDiv.style.left = (e.clientX - 260) + 'px';
                infoDiv.style.top = (e.clientY - 50) + 'px';
                infoDiv.style.display = 'block';
                result = JSON.parse(result)
                infoDiv.innerHTML = "chesstime:" + this.formatUnixtimestamp(result.chessTime) + "<br/>" + "chesscolor:" + result.chessColor + "<br/>" + "chessPlayer:" + result.chessPlayer + "<br/>" + "chessRefBlock:" + result.chessRefBlock
              }
            }).catch(this.showError)
          }).catch(this.showError)
      }, 200);
    },
    mouseup() {
      let infoDiv = document.getElementById('infoDiv');
      infoDiv.style.display = "none";;
    },
    hxPayListener(serialNumber, resp, name) {
      console.log("resp: " + JSON.stringify(resp))
      this.lastSerialNumber = serialNumber
      if (name === 'txhash') {
        const txid = resp
        this.lastTxid = txid
        hxPay.waitTransaction(this.nodeClient, txid)
          .then((tx) => {
            console.log("found tx", tx)
            // alert("transaction successfully")
            this.refreshUserInfo()
            this.refreshContractInfo()
            this.drawChessesBoardRepeat()
            this.showChatMsg()
          }, this.showError);
      } else {
        this.lastResponse = resp;
      }
    },
    refreshUserInfo() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.getAddrBalances(this.myAddress)
            .then(balances => {
              for (const balance of balances) {
                if (balance.asset_id === '1.3.0') {
                  console.log('user balances: ', balance)
                  this.myHxBalance = balance.amount / 100000
                }
              }
            }).catch(this.showError)
        })
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getUserBalance',
            this.myAddress
          ).then(result => {
            console.log('invokeContractOffline getUserBalance result: ', result)
            this.myContractHxBalance = result / 100000
          }).catch(this.showError)
        })
        .catch(this.showError)
    },
    refreshContractInfo() {
      this.nodeClient.afterInited()
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getBalanceUserCount',
            ''
          ).then(result => {
            console.log('invokeContractOffline getBalanceUserCount result: ', result)
            this.contractUserCount = result
          }).catch(this.showError)
        })
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getBonusPoolBalance',
            ''
          ).then(result => {
            console.log('invokeContractOffline getBonusPoolBalance result: ', result)
            this.bonusPoolBalance = result / 100000
          }).catch(this.showError)
        })
        .then(balances => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getContractRound',
            ''
          ).then(result => {
            console.log('invokeContractOffline getContractRound result: ', result)
            this.roundIndex = result
          }).catch(this.showError)
        })
        .then(balances => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getChessInfoUserCount',
            ''
          ).then(result => {
            console.log('invokeContractOffline getChessInfoUserCount result: ', result)
            this.roundParticipationCount = result
          }).catch(this.showError)
        })
        .then(() => {
          this.nodeClient.invokeContractOffline(
            this.myPubKey || dummyPubKey,
            this.contractAddress,
            'getChessInfoCount',
            ''
          ).then(result => {
            console.log('invokeContractOffline getChessInfoCount result: ', result)
            this.roundChessCount = result
          }).catch(this.showError)
        })
        .catch(this.showError)
    },
    withdrawBalanceFromContract() {
      this.nodeClient.afterInited()
        .then(() => {
          var assetId = "1.3.0";
          var to = this.contractAddress;
          var value = 0;
          var callFunction = "withdraw_balance"
          var callArgs = "";
          hxPay.simulateCall(assetId, to, value, callFunction, callArgs, {
            gasPrice: '0.00001',
            gasLimit: 5000,
            listener: this.hxPayListener.bind(this)
          });
        }).catch(this.showError);
    },
    //重新开发一轮游戏
    restartRound() {
      this.nodeClient.afterInited()
        .then(() => {
          var assetId = "1.3.0";
          var to = this.contractAddress;
          var value = 0;
          var callFunction = "start_new_round"
          var callArgs = "";
          hxPay.simulateCall(assetId, to, value, callFunction, callArgs, {
            gasPrice: '0.00001',
            gasLimit: 5000,
            listener: this.hxPayListener.bind(this)
          });
        }).catch(this.showError);
    },
    depositToContract() {
      this.nodeClient.afterInited()
        .then(() => {
          var assetId = "1.3.0";
          var to = this.contractAddress;
          var value = 0;
          hxPay.transferToContract(assetId, to, value, ['hi'], {
            gasPrice: '0.00001',
            gasLimit: 5000,
            listener: this.hxPayListener.bind(this)
          });
        }).catch(this.showError);
    },
    playChess(x, y) {
      this.nodeClient.afterInited()
        .then(() => {
          var assetId = "1.3.0";
          var to = this.contractAddress;
          var value = 0;
          var callFunction = "play_chess"
          var callArgs = parseInt((x + 1) * 1000 + (y + 1));
          hxPay.simulateCall(assetId, to, value, callFunction, callArgs, {
            gasPrice: '0.00001',
            gasLimit: 5000,
            listener: this.hxPayListener.bind(this)
          });
        }).catch(this.showError);
    },
    sendMessage() {
      this.nodeClient.afterInited()
        .then(() => {
          var assetId = "1.3.0";
          var to = this.contractAddress;
          var value = 0;
          var callFunction = "send_chat_message"

          var msgInput=this.messageInput
          this.messageInput=''
          var callArgs = Base64.encode(msgInput);
          hxPay.simulateCall(assetId, to, value, callFunction, callArgs, {
            gasPrice: '0.00001',
            gasLimit: 5000,
            listener: this.hxPayListener.bind(this)
          });
        }).catch(this.showError);
    },
    //浮点数相加
    FloatAdd(arg1, arg2) {
      var r1, r2, m;
      try { r1 = arg1.toString().split(".")[1].length } catch (e) { r1 = 0 }
      try { r2 = arg2.toString().split(".")[1].length } catch (e) { r2 = 0 }
      m = Math.pow(10, Math.max(r1, r2));
      return (arg1 * m + arg2 * m) / m;
    },
    //时间戳格式化
    formatUnixtimestamp(unixtimestamp) {
      var unixtimestamp = new Date(unixtimestamp * 1000);
      var year = 1900 + unixtimestamp.getYear();
      var month = "0" + (unixtimestamp.getMonth() + 1);
      var date = "0" + unixtimestamp.getDate();
      var hour = "0" + unixtimestamp.getHours();
      var minute = "0" + unixtimestamp.getMinutes();
      var second = "0" + unixtimestamp.getSeconds();
      return year + "-" + month.substring(month.length - 2, month.length) + "-" + date.substring(date.length - 2, date.length)
        + " " + hour.substring(hour.length - 2, hour.length) + ":"
        + minute.substring(minute.length - 2, minute.length) + ":"
        + second.substring(second.length - 2, second.length);
    },
    showError(err) {
      // alert(JSON.stringify(err))
    }
  }
})
