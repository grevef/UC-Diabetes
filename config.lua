Config = {}

Config.Integrations = {
    framework = "qbx", -- 'qbx' | 
    inventory = "ox", -- 'ox' | 
    notify = "ox", -- 'ox' | 
}

Config.ItemNames = {
    insulinPen = "insulinpen",
    energyTablet = "energytablet",
    bloodSugarMonitor = "bloodsugarmonitor",
}

Config.items = {
    insulin = {
        sugarDecrease = 5.0, -- Decreases sugar level by 5
        animation = {
            dict = "rcmpaparazzo1ig_4",
            clip = "miranda_shooting_up",
            duration = 6000,
            prop = {
                model = "prop_syringe_01",
                bone = 18905,
                pos = {0.12, 0.03, 0.02},
                rot = {10.0, 160.0, 10.0},
            }
        },
    },
    energyTablet = {
        sugarIncrease = 10.0, -- Increases sugar level by 10
        animation = {
            dict = "mp_suicide",
            clip = "pill",
            duration = 2500,
            prop = {
                model = "xm3_prop_xm3_pill_01a",
                bone = 58866,
                pos = {0.00, 0.00, 0.00},
                rot = {0.0, 0.0, 0.0},
            }
        },
    },
    bloodSugarMonitor = {
        animation = {
            dict = "cellphone@",
            clip = "cellphone_text_read_base", -- looped while the monitor is open
            flag = 49,
            prop = {
                model = "prop_amb_phone",
                bone = 28422,
                pos = {0.0, 0.0, 0.0,},
                rot = {0.0, 0.0, 0.0}, 
            }
        },
    },
}

Config.Monitor = {
    unit = "mg/dL", -- 'mg/dL' | 'mmol/L'
    targetLow = 70, -- reading (mg/dL) shown at Config.Effects.lowSugar.threshold
    targetHigh = 180, -- reading (mg/dL) shown at Config.Effects.highSugar.threshold
    testDuration = 5, -- countdown in seconds before the result is shown
    historySize = 10, -- readings kept in the monitor's history (per session)
    sound = { name = "Beep_Red", dict = "DLC_HEIST_HACKING_SNAKE_SOUNDS" }, -- played when the result shows
}

Config.Type1 = {
    SugarDecreaseAmount = 2.5,
    SugarDecreaseInterval = 5, -- Interval in minutes
}

Config.Type2 = {
    SugarDecreaseAmount = 3.0,
    SugarDecreaseInterval = 4, -- Interval in minutes
}

Config.Effects = {
    highSugar = {
        threshold = 80.0,
        screenEffect = "DrugsMichaelAliensFightIn",
        walkingSpeed = 0.3,
        animation = "MOVE_M@DRUNK@MODERATEDRUNK_HEAD_UP",
        healthLoss = 2.0,

    },
    lowSugar = {
        threshold = 20.0,
        screenEffect = "DrugsMichaelAliensFightIn",
        walkingSpeed = 0.3,
        animation = "MOVE_M@DRUNK@MODERATEDRUNK_HEAD_UP",
        healthLoss = 2.0,
    },
}