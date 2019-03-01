-- 合约状态  0 游戏未开始  1 游戏开始  2 游戏结束
-- 

type ChessInfo = {
    chessColor: int,
    chessTime: int,
    chessPlayer: string,
    chessRefBlock: int
}

type ChatMsgInfo = {
    msgSender: string,
    msgTime: int,
    msgContent: string
}

type Storage = {
    contractCreater: string,  -- 合约创建人
    contractRound: int,  -- 第几轮游戏
    contractState: int,  -- 合约状态
    bonusPoolBalance: int,  -- 奖金池余额
    balanceIndex: int,  -- 余额用户索引
    -- address_map (fast_map)   余额用户索引 -> 用户地址
    -- balance_map (fast_map)   用户地址 -> 用户余额
    chessinfoIndex: int,  -- 盘面棋子索引
    -- position_map (fast_map)   盘面棋子索引 -> 棋子位置
    -- chessinfo_map (fast_map)    棋子位置 -> 棋子信息
    roundWinColor: int, -- 本轮获胜颜色
    roundBonusBalance: Map<int>, -- 本轮奖金分配
    chatMessageIndex: int -- 聊天记录索引
    -- chatmsginfo_map (fast_map)   聊天记录索引 -> 聊天记录
}


var M = Contract<Storage>()


let chessBoardMaxSize: int = 1000
-- 棋盘大小 
let chessBoardSize: int = 19
-- 颜色种类 
let colorCount: int = 5
-- 胜利条件 相同颜色棋子数量
let chessCountWinCondition: int = 4
-- 开发者抽成 5%
let cutPercentage: number = 0.05
-- 允许投注资产类型
let betAssetSymbol: string = "HX"
-- 单笔投注金额
let betPrice: int = 10000
-- 资产精度
let assetPrecision: int = 100000


-------------------------util------------------------------------------
let function get_from_address()
    var fromAddress: string
    let prevContractId = get_prev_call_frame_contract_address()
    if prevContractId and is_valid_contract_address(prevContractId) then
        fromAddress = prevContractId
    else
        fromAddress = caller_address
    end
    return fromAddress
end

let function check_address(addr: string)
	var result = is_valid_contract_address(addr)
	if result then
        return error("address is contract address")
    end
    result = is_valid_address(addr)
    if not result then
        return error("address format error")
    end
    return result
end

let function check_chess_position(position: int)
    let row: int = tointeger(position / chessBoardMaxSize)
    let column: int = tointeger(position % chessBoardMaxSize)
    if (row < 1) or (row > chessBoardSize) or (column < 1) or (column > chessBoardSize) then
        return error("invalid chess position value")
    end
end

let function parse_args(arg: string, count: int, error_msg: string)
    if not arg then
        return error(error_msg)
    end
    let parsed = string.split(arg, ',')
    if (not parsed) or (#parsed ~= count) then
        return error(error_msg)
    end
    return parsed
end

-- 根据row column获取color
let function get_color_by_row_column(m: table, row: int, column: int)
    if (row < 1) or (row > chessBoardSize) or (column < 1) or (column > chessBoardSize) then
        return 0
    else
        let chessPosition = row * chessBoardMaxSize + column

        let tmp = fast_map_get("chessinfo_map", tostring(chessPosition))
        if (not tmp) then
            return 0
        end

        let chessInfoStr = tostring(tmp)
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end

        return chessInfo.chessColor
    end
end

-- 判断横是否达到胜利条件
let function is_win_1(m: table, color: int, position: int)
    let row = tointeger(position / chessBoardMaxSize)
    let column = tointeger(position % chessBoardMaxSize)

    var row2: int
    var column2: int
    var color2: int
    var sameColorCount: int = 1
    
    -- 向左寻找
    row2 = row
    column2 = column
  
    while(true)
    do
        column2 = column2 - 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    -- 向右寻找
    row2 = row
    column2 = column

    while(true)
    do
        column2 = column2 + 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    return false
end

-- 判断竖是否达到胜利条件
let function is_win_2(m: table, color: int, position: int)
    let row = tointeger(position / chessBoardMaxSize)
    let column = tointeger(position % chessBoardMaxSize)

    var row2: int
    var column2: int
    var color2: int
    var sameColorCount: int = 1
    -- 向上寻找
    row2 = row
    column2 = column
  
    while(true)
    do
        row2 = row2 - 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    -- 向下寻找
    row2 = row
    column2 = column

    while(true)
    do
        row2 = row2 + 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    return false
end

-- 判断左斜线是否达到胜利条件
let function is_win_3(m: table, color: int, position: int)
    let row = tointeger(position / chessBoardMaxSize)
    let column = tointeger(position % chessBoardMaxSize)

    var row2: int
    var column2: int
    var color2: int
    var sameColorCount: int = 1
    -- 向右上寻找
    row2 = row
    column2 = column
  
    while(true)
    do
        row2 = row2 - 1
        column2 = column2 + 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    -- 向左下寻找
    row2 = row
    column2 = column

    while(true)
    do
        row2 = row2 + 1
        column2 = column2 - 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    return false
end

-- 判断右斜线是否达到胜利条件
let function is_win_4(m: table, color: int, position: int)
    let row = tointeger(position / chessBoardMaxSize)
    let column = tointeger(position % chessBoardMaxSize) 

    var row2: int
    var column2: int
    var color2: int
    var sameColorCount: int = 1
    -- 向左上寻找
    row2 = row
    column2 = column
 
    while(true)
    do
        row2 = row2 - 1
        column2 = column2 - 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    -- 向右下寻找
    row2 = row
    column2 = column

    while(true)
    do
        row2 = row2 + 1
        column2 = column2 + 1
        color2 = tointeger(get_color_by_row_column(m, row2, column2))
        if (color2 == color) then
            sameColorCount = sameColorCount + 1
        else
            break
        end
        
        if (sameColorCount == chessCountWinCondition) then
            return true
        end
    end

    return false
end

-- 查询用户余额
let function query_user_balance(m: table, userAddr: string)
    var userBalance = 0
    let tmp = fast_map_get("balance_map", userAddr)
    if tmp then
        userBalance = tointeger(tostring(tmp))
    end
    return userBalance
end

-- 增加用户余额
let function add_user_balance(m: table, userAddr: string, balance: int)
    var userBalance = 0
    let tmp = fast_map_get("balance_map", userAddr)
    if (not tmp) then
        m.storage.balanceIndex = tointeger(m.storage.balanceIndex) + 1
        fast_map_set("address_map", tostring(m.storage.balanceIndex), userAddr)
    else
        userBalance = tointeger(tostring(tmp))
    end

    userBalance = userBalance + balance
    fast_map_set("balance_map", userAddr, tostring(userBalance))
end

-- 扣除用户余额
let function sub_user_balance(m: table, userAddr: string, balance: int)
    var userBalance = 0
    let tmp = fast_map_get("balance_map", userAddr)
    if (not tmp) then
        return error("sub_user_balance | can't find userAddr: " .. userAddr)
    else
        userBalance = tointeger(tostring(tmp))
    end

    if userBalance < balance then
        return error("sub_user_balance | not enough balance")
    end

    userBalance = userBalance - balance
    fast_map_set("balance_map", userAddr, tostring(userBalance))
end

-- 查询某个位置的棋子信息
let function query_chess_info(m: table, chess_position: int)
    check_chess_position(chess_position)

    var chessInfo = ""
    let tmp = fast_map_get("chessinfo_map", tostring(chess_position))
    if tmp then
        chessInfo = tostring(tmp)
    end
    return chessInfo  
end

------------------------- online ------------------------------
function M:init()
    self.storage.contractCreater = caller_address
    self.storage.contractRound = 0
    self.storage.contractState = 0
    self.storage.bonusPoolBalance = 0

    self.storage.balanceIndex = 0
    -- address_map (fast_map)
    -- balance_map (fast_map)
    self.storage.chessinfoIndex = 0
    -- position_map (fast_map)
    -- chessinfo_map (fast_map)
    self.storage.roundWinColor = 0
    self.storage.roundBonusBalance = {}
    self.storage.chatMessageIndex = 0
end


function M:on_deposit_asset(jsonstrArgs: string)
    let arg = json.loads(jsonstrArgs)
    let addedAmount = tointeger(arg.num)
    let symbol = tostring(arg.symbol)

	if (not addedAmount) or (addedAmount <= 0) then
		 return error("deposit should greater than 0")
	end

	if (not symbol) or (#symbol < 1) then
		 return error("on_deposit_asset arg wrong")
    end
    
    if symbol ~= betAssetSymbol then
        return error("only support deposit asset " .. betAssetSymbol)
    end

	let fromAddress: string = caller_address

    -- 调整余额
    add_user_balance(self, fromAddress, addedAmount)

    emit EV_UserDepositAsset(fromAddress .. "," .. tostring(addedAmount))
end


function M:start_new_round(_: string)
    if (self.storage.contractState ~= 0) and (self.storage.contractState ~= 2) then
        return error("can't start a new round game at current state")
    end

    self.storage.contractRound = self.storage.contractRound + 1
    self.storage.contractState = 1

    -- 初始化棋盘
    for i=1,self.storage.chessinfoIndex do
        let chess_position: string = tostring(fast_map_get("position_map", tostring(i)))

        fast_map_set("chessinfo_map", chess_position, nil)
        fast_map_set("position_map", tostring(i), nil)
    end

    self.storage.chessinfoIndex = 0

    self.storage.roundWinColor = 0
    self.storage.roundBonusBalance = {}

    emit EV_StartNewRound(tostring(self.storage.contractRound))
end


function M:play_chess(args: string)
    let chessPositionStr: string = args
    let chessPosition: int = tointeger(args)
    let fromAddress: string = caller_address

    if (self.storage.contractState == 0) or (self.storage.contractState == 2) then
        return error("can't play chess at current state")
    end

    -- 当前是否允许下子
    var lastChessTime: int
    if self.storage.chessinfoIndex == 0 then
        lastChessTime = 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        lastChessTime = chessInfo.chessTime
    end

    if tointeger(get_chain_now()) <= lastChessTime then
        return error("can't play chess at current time")
    end

    -- 落子位置检查
    check_chess_position(chessPosition)

    let tmp = fast_map_get("chessinfo_map", chessPositionStr)
    if tmp then
        return error("position been token before")
    end

    -- 用户余额检查
    var userBalance = query_user_balance(self, fromAddress)

    if userBalance < betPrice then 
        return error("not enough balance")
    end

    -- 投注
    sub_user_balance(self, fromAddress, betPrice)

    -- 奖池
    self.storage.bonusPoolBalance = self.storage.bonusPoolBalance + betPrice

    let random: int = tointeger(get_chain_random())
    let chessColor: int = tointeger((random % colorCount) + 1)
    let chessTime: int = tointeger(get_chain_now())
    let chessRefBlock: int = tointeger(get_header_block_num()) + 1

    var chessInfo = ChessInfo()
    chessInfo.chessColor = chessColor
    chessInfo.chessTime = chessTime
    chessInfo.chessPlayer = fromAddress
    chessInfo.chessRefBlock = chessRefBlock
    
    let chessInfoStr: string = json.dumps(chessInfo)

    -- 记录落子信息
    self.storage.chessinfoIndex = self.storage.chessinfoIndex + 1
    fast_map_set("position_map", tostring(self.storage.chessinfoIndex), chessPositionStr)
    fast_map_set("chessinfo_map", chessPositionStr, chessInfoStr)

    -- 检查是否满足胜利条件
    -- 达到胜利条件 抽成+奖励    未达到胜利条件 继续
    if is_win_1(self, chessColor, chessPosition) or is_win_2(self, chessColor, chessPosition) or is_win_3(self, chessColor, chessPosition) or is_win_4(self, chessColor, chessPosition) then
        var weightTotalWin: int = 0
        var winner: Map<int> = {}
        for i=1,self.storage.chessinfoIndex do
            let chessPositionStr2: string = tostring(fast_map_get("position_map", tostring(i)))
            let chessInfoStr2: string = query_chess_info(self, tointeger(chessPositionStr2))
            
            let chessInfo2: ChessInfo = totable(json.loads(chessInfoStr2))
            if (not chessInfo2) then
                return error("assert: nil chessInfo2")
            end

            if chessInfo2.chessColor == chessColor then
                var winnerWeight: int = 0
                let tmp = winner[chessInfo2.chessPlayer]
                if tmp then
                    winnerWeight = tointeger(tmp)
                end
                winner[chessInfo2.chessPlayer] = winnerWeight + 1
                weightTotalWin = weightTotalWin + 1
            end
        end

        self.storage.roundWinColor = chessInfo.chessColor

        -- 抽成
        let originbonusPoolBalance: int = self.storage.bonusPoolBalance
        let cutAmount: int = tointeger(originbonusPoolBalance * cutPercentage)
        add_user_balance(self, self.storage.contractCreater, cutAmount)
        self.storage.bonusPoolBalance = self.storage.bonusPoolBalance - cutAmount

        emit EV_CreatorCut(tostring(self.storage.contractRound) .. "," .. self.storage.contractCreater .. "," .. tostring(cutAmount))

        -- 发奖
        for k, v in pairs(totable(winner)) do 
            let userAddr: string = tostring(k)
            let bonusAmount: int = tointeger(tonumber(originbonusPoolBalance) * tonumber(1 - cutPercentage) * tonumber(v) / tonumber(weightTotalWin))
            add_user_balance(totable(self), userAddr, bonusAmount)
            self.storage.bonusPoolBalance = self.storage.bonusPoolBalance - bonusAmount
            self.storage.roundBonusBalance[userAddr] = bonusAmount

            emit EV_BonusAward(tostring(self.storage.contractRound) .. "," .. userAddr .. "," .. tostring(bonusAmount))
        end

        -- 本轮游戏结束
        self.storage.contractState = 2

        emit EV_RoundFinished(tostring(self.storage.contractRound))

        return
    end

    -- 检查是否无法达到胜利条件 （棋盘棋子已满）
    -- 达到条件 不抽成+退款    未达到条件 继续
    if self.storage.chessinfoIndex == (chessBoardSize*chessBoardSize) then
        var participant: Map<int> = {}
        for i=1,self.storage.chessinfoIndex do
            let chessPositionStr3: string = tostring(fast_map_get("position_map", tostring(i)))
            let chessInfoStr3: string = query_chess_info(self, tointeger(chessPositionStr3))
            
            let chessInfo3: ChessInfo = totable(json.loads(chessInfoStr3))
            if (not chessInfo3) then
                return error("assert: nil chessInfo3")
            end

            var participantWeight: int = 0
            let tmp = participant[chessInfo3.chessPlayer]
            if tmp then
                participantWeight = tointeger(tmp)
            end
            participant[chessInfo3.chessPlayer] = participantWeight + 1 
        end

        -- 退款
        for k, v in pairs(totable(participant)) do 
            let refundAmount: int = tointeger(tonumber(betPrice) * tonumber(v))
            add_user_balance(totable(self), tostring(k), refundAmount)
            self.storage.bonusPoolBalance = self.storage.bonusPoolBalance - refundAmount

            emit EV_ReFundAsset(tostring(self.storage.contractRound) .. "," .. tostring(k) .. "," .. tostring(refundAmount))
        end

        -- 本轮游戏结束
        self.storage.contractState = 2

        emit EV_RoundFinished(tostring(self.storage.contractRound))

        return
    end
end


function M:send_chat_message(chatMsgB64Str: string)
    self.storage.chatMessageIndex = tointeger(self.storage.chatMessageIndex) + 1
    let chatMessageIndexStr: string = tostring(self.storage.chatMessageIndex)

    let msgTime: int = tointeger(get_chain_now())

    var chatMsgInfo = ChatMsgInfo()
    chatMsgInfo.msgSender = caller_address
    chatMsgInfo.msgTime = msgTime
    chatMsgInfo.msgContent = chatMsgB64Str

    let chatMsgInfoStr: string = json.dumps(chatMsgInfo)

    fast_map_set("chatmsginfo_map", chatMessageIndexStr, chatMsgInfoStr)

    emit EV_SendChatMsg(caller_address .. "," .. chatMsgB64Str)

    return
end


-- 管理员强行结束本轮游戏
function M:force_close_round()
    if self.storage.contractCreater ~= caller_address then
        return error("caller_address has no authority to force to close this round game")
    end   

    if (self.storage.contractState == 0) or (self.storage.contractState == 2) then
        return error("can't force to close this round game at current state")
    end

    var participant: Map<int> = {}
    for i=1,self.storage.chessinfoIndex do
        let chessPositionStr3: string = tostring(fast_map_get("position_map", tostring(i)))
        let chessInfoStr3: string = query_chess_info(self, tointeger(chessPositionStr3))
        
        let chessInfo3: ChessInfo = totable(json.loads(chessInfoStr3))
        if (not chessInfo3) then
            return error("assert: nil chessInfo3")
        end

        var participantWeight: int = 0
        let tmp = participant[chessInfo3.chessPlayer]
        if tmp then
            participantWeight = tointeger(tmp)
        end
        participant[chessInfo3.chessPlayer] = participantWeight + 1 
    end

    -- 退款
    for k, v in pairs(totable(participant)) do 
        let refundAmount: int = tointeger(tonumber(betPrice) * tonumber(v))
        add_user_balance(self, tostring(k), refundAmount)
        self.storage.bonusPoolBalance = self.storage.bonusPoolBalance - refundAmount

        emit EV_ReFundAsset(tostring(self.storage.contractRound) .. "," .. tostring(k) .. "," .. tostring(refundAmount))
    end

    -- 本轮游戏结束
    self.storage.contractState = 2

    emit EV_RoundFinished(tostring(self.storage.contractRound))
end


function M:withdraw_balance(args: string)
    var argsNumber: number = tonumber(args)
    argsNumber = argsNumber * tonumber(assetPrecision)

    let balanceWithdraw: int = tointeger(argsNumber)
    if balanceWithdraw <= 0 then
        return error("invalid withdraw balance")
    end

	let fromAddress: string = caller_address

    sub_user_balance(self, fromAddress, balanceWithdraw)

	let res: int = transfer_from_contract_to_address(fromAddress, betAssetSymbol, balanceWithdraw)
	if res ~= 0 then
		return error("transfer from contract to " .. fromAddress .. " amount " .. tostring(balanceWithdraw) .." symbol " .. betAssetSymbol .. " error, error code is " .. tostring(res))
    end
    
    emit EV_UserWithdrawBalance(fromAddress .. "," .. tostring(balanceWithdraw))
end


-- 这个方法只有在合约发生异常情况 导致bonusPool中的余额无法取出时才应该被使用
function M:withdraw_bonus(args: string)
    var argsNumber: number = tonumber(args)
    argsNumber = argsNumber * tonumber(assetPrecision)

    if self.storage.contractCreater ~= caller_address then
        return error("caller_address has no authority to withdraw bonus balance")
    end   

    if (self.storage.contractState ~= 0) and (self.storage.contractState ~= 2) then
        return error("can't withdraw bonus balance at current state")
    end

    let fromAddress: string = caller_address

    let balanceWithdraw: int = tointeger(argsNumber)
    if balanceWithdraw <= 0 then
        return error("invalid withdraw bonus balance")
    end

    if balanceWithdraw > self.storage.bonusPoolBalance then
        return error("not enough bonus balance")
    end

    self.storage.bonusPoolBalance = self.storage.bonusPoolBalance - balanceWithdraw

    let res: int = transfer_from_contract_to_address(fromAddress, betAssetSymbol, balanceWithdraw)
	if res ~= 0 then
		return error("transfer from contract to " .. fromAddress .. " amount " .. tostring(balanceWithdraw) .." symbol " .. betAssetSymbol .. " error, error code is " .. tostring(res))
    end
    
    emit EV_CreatorWithdrawBonus(fromAddress .. "," .. tostring(balanceWithdraw))   
end


function M:on_destroy()
    return error("can't destroy contract")
end


------------------------- offline ------------------------------
offline function M:getContractCreater(_: string)
    return self.storage.contractCreater
end


offline function M:getContractRound(_: string)
    return self.storage.contractRound
end


offline function M:getContractState(_: string)
    if self.storage.contractState == 0 then
        return "Round_Not_Start"
    elseif self.storage.contractState == 1 then
        return "Round_Started"
    elseif self.storage.contractState == 2 then
        return "Round_Finished"
    else
        return "Invalid_State"
    end
end


offline function M:getLastPlayer(_: string)
    if self.storage.chessinfoIndex == 0 then
        return ""
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        return chessInfo.chessPlayer
    end
end


offline function M:getLastPlayTime(_: string)
    if self.storage.chessinfoIndex == 0 then
        return 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        return chessInfo.chessTime
    end
end


offline function M:getLastChessColor(_: string)
    if self.storage.chessinfoIndex == 0 then
        return 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        return chessInfo.chessColor
    end
end


offline function M:getLastChessRefBlock(_: string)
    if self.storage.chessinfoIndex == 0 then
        return 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        return chessInfo.chessRefBlock
    end
end


offline function M:getLastChessPosition(_: string)
    if self.storage.chessinfoIndex == 0 then
        return 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        -- 确保通过chessPosition能查询到有效的chessInfo
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        return tointeger(chessPositionStr)
    end
end


offline function M:getBonusPoolBalance(_: string)
    return self.storage.bonusPoolBalance
end


offline function M:getBalanceUserCount(_: string)
    return self.storage.balanceIndex
end


offline function M:getUserBalance(userAddress: string)
    check_address(userAddress)
    return query_user_balance(self, userAddress)
end


offline function M:getBalanceByIndex(args: string)
	let parsed = parse_args(args, 2, "error of arg format: startIndex,endIndex")
	let startIndex = tointeger(parsed[1])
	let endIndex = tointeger(parsed[2])
	if (startIndex < 1) or (startIndex > self.storage.balanceIndex) then
		return error("startIndex should in [1, balanceIndex]")
	end

    if (endIndex < 1) or (endIndex > self.storage.balanceIndex) then
		return error("endIndex should in [1, balanceIndex]")
    end
    
    if startIndex > endIndex then
        return error("startIndex should not greater than endIndex")
    end

    var retArray = []
    for i=startIndex,endIndex do 
        let addrBalance = {}
        let userAddress = tostring(fast_map_get("address_map", tostring(i)))
        let userBalance = query_user_balance(self, userAddress)
        addrBalance[userAddress] = userBalance
        retArray[#retArray+1] = addrBalance
    end
    
    let retStr = json.dumps(totable(retArray))
    return retStr
end


offline function M:getChessInfoCount(_: string)
    return self.storage.chessinfoIndex
end


offline function M:getChessInfo(chessPositionStr: string)
    let chessPosition: int = tointeger(chessPositionStr)
    return query_chess_info(self, chessPosition)
end


offline function M:getChessInfoByIndex(args: string)
	let parsed = parse_args(args, 2, "error of arg format: startIndex,endIndex")
	let startIndex = tointeger(parsed[1])
	let endIndex = tointeger(parsed[2])
	if (startIndex < 1) or (startIndex > self.storage.chessinfoIndex) then
		return error("startIndex should in [1, chessinfoIndex]")
	end

    if (endIndex < 1) or (endIndex > self.storage.chessinfoIndex) then
		return error("endIndex should in [1, chessinfoIndex]")
    end
    
    if startIndex > endIndex then
        return error("startIndex should not greater than endIndex")
    end

    var retArray = []
    for i=startIndex,endIndex do 
        var positionInfo: Map<string> = {}
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(i)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        positionInfo[chessPositionStr] = chessInfoStr
        retArray[#retArray+1] = positionInfo
    end  

    let retStr = json.dumps(totable(retArray))
    return retStr
end


offline function M:getChessInfoUserCount(_: string)
    var chessInfoUser: Map<int> = {}
    var chessInfoUserCount :int = 0
    for i=1,self.storage.chessinfoIndex do
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(i)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end

        let tmp = chessInfoUser[chessInfo.chessPlayer]
        if (not tmp) then
            chessInfoUserCount = chessInfoUserCount + 1
            chessInfoUser[chessInfo.chessPlayer] = 0
        end
    end

    return chessInfoUserCount
end


offline function M:isAllowPlay(_: string)
    if self.storage.contractState == 0 or self.storage.contractState == 2 then
        return false
    end

    var lastChessTime: int
    if self.storage.chessinfoIndex == 0 then
        lastChessTime = 0
    else
        let chessPositionStr: string = tostring(fast_map_get("position_map", tostring(self.storage.chessinfoIndex)))
        let chessInfoStr: string = query_chess_info(self, tointeger(chessPositionStr))
        
        let chessInfo: ChessInfo = totable(json.loads(chessInfoStr))
        if (not chessInfo) then
            return error("assert: nil chessInfo")
        end
        lastChessTime = chessInfo.chessTime
    end

    if tointeger(get_chain_now()) <= lastChessTime then
        return false
    end

    return true
end


offline function M:getRoundWinColor(_: string)
    return self.storage.roundWinColor
end


offline function M:getRoundBonusBalance(addr: string)
    var userBonusBalance: int = self.storage.roundBonusBalance[addr]
    if (not userBonusBalance) then
        userBonusBalance = 0
    end
    return userBonusBalance
end


offline function M:getBetPrice(_: string)
    return tonumber(betPrice) / tonumber(assetPrecision)
end


offline function M:getChatMsgIndex(_: string)
    return self.storage.chatMessageIndex
end


offline function M:getChatMsgByIndex(args: string)
    let parsed = parse_args(args, 2, "error of arg format: startIndex,endIndex")
    let startIndex = tointeger(parsed[1])
    let endIndex = tointeger(parsed[2])
    if (startIndex < 1) or (startIndex > self.storage.chatMessageIndex) then
        return error("startIndex should in [1, chatMessageIndex]")
    end

    if (endIndex < 1) or (endIndex > self.storage.chatMessageIndex) then
        return error("endIndex should in [1, chatMessageIndex]")
    end

    if startIndex > endIndex then
        return error("startIndex should not greater than endIndex")
    end

    var retArray = []
    for i=startIndex,endIndex do
        let chatMsgInfoStr: string = tostring(fast_map_get("chatmsginfo_map", tostring(i)))
        retArray[#retArray+1] = chatMsgInfoStr
    end

    return retArray
end


return M

