PluginInfo@ GetPluginInfo()
{
    auto info = PluginInfo();
    info.Name = "TSP Solver";
    info.Author = "Jsap";
    info.Version = "v1.3.0";
    info.Description = "Tool to find shortest path between some points";
    return info;
}

void Main() {
    RegisterCustomCommand("add_point", "Adds a point from cam pos to tsp solver point list", AddPoint);
    RegisterCustomCommand("add_points_from_replay", "Adds the start, all the cp and fin points from a replay to tsp solver point list", GetFromReplay);
    RegisterVariable("jsap_tsp_closed", true);
    RegisterVariable("jsap_tsp_num_points", 0);
    RegisterVariable("jsap_tsp_results", "");
    RegisterVariable("jsap_tsp_it_count", 100);
    RegisterVariable("jsap_tsp_elim", "");
    RegisterVariable("jsap_tsp_best", 9999999);
    RegisterVariable("jsap_tsp_best_points_str", "");
    GetVariable("jsap_tsp_best", bestRun);
    GetVariable("jsap_tsp_best_points_str", bestRunPoints_str);
    GetVariable("jsap_tsp_results", results);
    GetVariable("jsap_tsp_num_points", num_points);
    GetVariable("jsap_tsp_elim", elimTable);
    for (int i = 0; i < num_points; i++) {
        RegisterVariable("jsap_tsp_point" + Text::FormatInt(i), "0 0 0");
        RegisterVariable("jsap_tsp_point_name" + Text::FormatInt(i), "");
    }
}

void AddPoint(int fromTime, int toTime, const string&in commandLine, const array<string>&in args) {
    auto cam = GetCurrentCamera();
    if (@cam != null) {
        RegisterVariable("jsap_tsp_point" + Text::FormatInt(num_points + 1), "0 0 0");
        RegisterVariable("jsap_tsp_point_name" + Text::FormatInt(num_points + 1), "");
        SetVariable("jsap_tsp_point" + Text::FormatInt(num_points + 1), cam.Location.Position.ToString());
        SetVariable("jsap_tsp_point_name" + Text::FormatInt(num_points + 1), "cp" + Text::FormatInt(num_points + 1));
        SetVariable("jsap_tsp_num_points", ++num_points);
    }
}

void GetFromReplay(int fromTime, int toTime, const string&in commandLine, const array<string>&in args) {
    SetVariable("jsap_tsp_num_points", 0);
    num_points = 0;
    for (int i = 0; i < int(cpList.Length); i++) {
        RegisterVariable("jsap_tsp_point" + Text::FormatInt(num_points + 1), "0 0 0");
        RegisterVariable("jsap_tsp_point_name" + Text::FormatInt(num_points + 1), "");
        string inter;
        for (int j = 0; j < 3; j++) {
            if (j != 0)
                inter += " ";
            inter += Text::FormatFloat(cpList[i][j], "", 0, 3);
        }
        SetVariable("jsap_tsp_point" + (num_points + 1), inter);
        if (i == 0) {
            SetVariable("jsap_tsp_point_name" + (num_points + 1), "start");
        }
        else if (i == int(cpList.Length - 1)) {
            SetVariable("jsap_tsp_point_name" + (num_points + 1), "fin");
        }
        else {
            SetVariable("jsap_tsp_point_name" + (num_points + 1), "cp" + num_points);
        }
        SetVariable("jsap_tsp_num_points", ++num_points);
    }
    elimTable = "";
    for (int i = 1; i < num_points; i++) {
        elimTable += GetVariableI("jsap_tsp_point_name" + i) + " " + GetVariableI("jsap_tsp_point_name" + (i + 1)) + "\n";
    }
}

void OnSimulationBegin(SimulationManager@ simManager) {
    isInSim = true;
    cpList.Clear();
    cpList.Add(simManager.Dyna.CurrentState.Location.Position);
}

void OnCheckpointCountChanged(SimulationManager@ simManager, int current, int target) {
    if (isInSim)
        cpList.Add(simManager.Dyna.CurrentState.Location.Position);
    if (simManager.PlayerInfo.RaceFinished)
        isInSim = false;
}

void OnLapCountChanged(SimulationManager@ simManager, int current, int target) {
    isInSim = false;
}


bool isInSim = false;
array<vec3> cpList;

string closestCpName;
int num_points;
float bestRun;
string bestRunPoints_str;
array<int> bestRunPoints;
array<array<int>> bestStepsList;
string results;
string elimTable;
array<array<float>> costMat;
float alpha = 1;
float beta = 5;
float p = 0;
int m = 50;
void Render() {
    if (UI::Begin("TSP Solver")) {
        if (UI::CollapsingHeader("points")) {
            UI::Text("Use _ instead of space when renaming!!!");
            for (int i = 1; i < num_points + 1; i++) {
                RegisterVariable("jsap_tsp_point" + Text::FormatInt(i), "0 0 0");
                RegisterVariable("jsap_tsp_point_name" + Text::FormatInt(i), "");
                UI::InputTextVar(" ##" + Text::FormatInt(i), "jsap_tsp_point_name" + Text::FormatInt(i)); //thank you aijundi you're a genius
                UI::DragFloat3Var("  ##" + Text::FormatInt(i), "jsap_tsp_point" + Text::FormatInt(i));
                UI::SameLine();
                if (UI::Button("Cam copy##" + Text::FormatInt(i))) {
                    auto cam = GetCurrentCamera();
                    if (@cam != null) {
                        SetVariable("jsap_tsp_point" + Text::FormatInt(i), cam.Location.Position.ToString());
                    }
                }
                UI::SameLine();
                if (UI::Button("Delete##" + Text::FormatInt(i))) {
                    for (int j = i; j < num_points; j++) {
                        SetVariable("jsap_tsp_point" + Text::FormatInt(j), GetVariableI("jsap_tsp_point" + Text::FormatInt(j + 1)));
                        SetVariable("jsap_tsp_point_name" + Text::FormatInt(j), GetVariableI("jsap_tsp_point_name" + Text::FormatInt(j + 1)));
                    }
                    SetVariable("jsap_tsp_point" + Text::FormatInt(num_points), "0 0 0");
                    SetVariable("jsap_tsp_point_name" + Text::FormatInt(num_points), "");
                    SetVariable("jsap_tsp_num_points", --num_points);
                }
            }
            if (UI::Button("Add from cam pos")) {
                auto cam = GetCurrentCamera();
                if (@cam != null) {
                    RegisterVariable("jsap_tsp_point" + Text::FormatInt(num_points + 1), "0 0 0");
                    RegisterVariable("jsap_tsp_point_name" + Text::FormatInt(num_points + 1), "");
                    SetVariable("jsap_tsp_point" + Text::FormatInt(num_points + 1), cam.Location.Position.ToString());
                    SetVariable("jsap_tsp_point_name" + Text::FormatInt(num_points + 1), "cp" + Text::FormatInt(num_points + 1));
                    SetVariable("jsap_tsp_num_points", ++num_points);
                }
            }
        }
        UI::Separator();
        UI::CheckboxVar("Closed path?", "jsap_tsp_closed");
        UI::TextDimmed("Enable it if the car should return to the start pos at the end");
        UI::InputIntVar("Iterations", "jsap_tsp_it_count");
        UI::TextDimmed("The game might freeze for a while, so be careful with this");
        UI::Text("Whitelist table");
        UI::TextDimmed("Put point names here to tell the tsp solver that you can go there");
        UI::TextDimmed("For example: 'cp1 cp3' means you can go from cp1 to cp3 (cp3 to cp1 isnt included)");
        UI::TextDimmed("'cp1 cp3 cp4' is the same as: 'cp1 cp3' + 'cp1 cp4");
        UI::TextDimmed("List these pairs with in each line, the points should be separated by 1 space");
        UI::InputTextMultiline("##", elimTable);
        UI::Separator();
        if (UI::Button("Run TSP solver")) {
            for (int god = 0; god < 1; god++) {
                int n;
                array<float> inter;
                GetVariable("jsap_tsp_it_count", n);
                array<array<float>> costMatOg = ConstructCostMat();
                for (int i = 0; i < num_points; i++) {
                    inter.Add(0);
                }
                costMat.Clear();
                for (int i = 0; i < num_points; i++) {
                    costMat.Add(inter);
                }
                float best = 9999999;
                array<int> bestSteps;
                array<array<float>> pher;
                SetVariable("jsap_tsp_elim", elimTable);
                array<string> splitElimTable = elimTable.Split("\n");
                for (int i = 0; i < int(splitElimTable.Length); i++) {
                    array<string> elimRow = splitElimTable[i].Split(" ");
                    if (elimRow.Length == 1) {
                        continue;
                    }
                    int elimFrom = IndexFromPointName(elimRow[0]);
                    if (elimFrom == -1) {
                        log("One of the points aren't found", Severity::Error);
                        continue;
                    }
                    for (int j = 1; j < int(elimRow.Length); j++) {
                        int elimTo = IndexFromPointName(elimRow[j]);
                        if (elimTo == -1) {
                            log("One of the points aren't found", Severity::Error);
                            continue;
                        }
                        costMat[elimTo][elimFrom] = costMatOg[elimTo][elimFrom];
                    }
                }
                inter.Clear();
                for (int i = 0; i < num_points; i++) {
                    inter.Add(1);
                }
                for (int i = 0; i < num_points; i++) {
                    pher.Add(inter);
                }
                inter.Clear();
                for (int i = 0; i < num_points; i++) {
                    inter.Add(0);
                }
                for (int i = 0; i < n; i++) {
                    array<array<float>> pherCopy = pher;
                    pherCopy = MatMulScal(pherCopy, 1-p);
                    for (int k = 0; k < m; k++) {
                        array<array<float>> costMatCopy = costMat;
                        costMatCopy[0] = inter;
                        bool isClosed;
                        int extra;
                        GetVariable("jsap_tsp_closed", isClosed);
                        if (isClosed) {
                            extra = 0;
                        }
                        else {
                            extra = -1;
                            costMatCopy[num_points - 1] = inter;
                        }
                        float cost = 0;
                        array<int> steps(num_points);
                        steps[0] = 1;
                        int step_to;
                        //log("yes");
                        for (int l = 0; l < num_points + extra; l++) {
                            if (l == num_points + extra - 1) {
                                if (isClosed) {
                                    costMatCopy[0] = costMat[0];
                                }
                                else {
                                    costMatCopy[num_points - 1] = costMat[num_points - 1];
                                }
                            }
                            step_to = SelStep(steps[l], costMatCopy, pher);
                            if (step_to == -1) {
                                k++;
                                break;
                            }
                            cost += costMat[step_to - 1][steps[l] - 1];
                            costMatCopy[step_to - 1] = inter;
                            steps[l + 1] = step_to;
                            //log(Text::FormatInt(step_to));
                        }
                        if (step_to == -1)
                            continue;
                        if (cost < best) {
                            best = cost;
                            bestSteps = steps;
                            //log(Text::FormatFloat(best, "", 0, 2));
                            for (int yey = 0; yey < int(steps.Length); yey++) {
                                //log(Text::FormatInt(steps[yey]));
                            }
                        }
                        for (int s = 0; s < num_points - 1; s++) {
                            pherCopy[steps[s + 1] - 1][steps[s] - 1] += 1/cost;
                        }
                    }
                    pher = pherCopy;
                }
                bestStepsList.Add(bestSteps);
                string results_points;
                for (int i = 0; i < int(bestSteps.Length); i++) {
                    results_points += " " + GetVariableI("jsap_tsp_point_name" + Text::FormatInt(bestSteps[i]));
                }
                if (best < bestRun) {
                    bestRun = best;
                    bestRunPoints = bestSteps;
                    bestRunPoints_str = results_points;
                    SetVariable("jsap_tsp_best", bestRun);
                    SetVariable("jsap_tsp_best_points_str", bestRunPoints_str);
                }
                results += Text::FormatFloat(best, "", 0, 2) + ":" + results_points + "\n";
                SetVariable("jsap_tsp_results", results);
            }
        }
        UI::TextDimmed("It's recommended to rerun it a few times");

        UI::TextWrapped(results);
        UI::Dummy(vec2(0, 5));
        UI::Text("Best:");
        UI::TextWrapped(Text::FormatFloat(bestRun, "", 0, 2) + ":" + bestRunPoints_str);
        if(UI::Button("Clear records")) {
            results = "";
            bestRun = 9999999;
            bestRunPoints_str = "";
            SetVariable("jsap_tsp_results", results);
        }
        UI::SameLine();
        if(UI::Button("Soft Permutations")) {
            bool isClosed;
            int extra;
            GetVariable("jsap_tsp_closed", isClosed);
            if (isClosed) {
                extra = 0;
            }
            else {
                extra = -1;
            }
            array<int> inter = bestRunPoints;
            for (int s = 1; s < num_points + extra - 1; s++) {
                for (int i = 1; i < num_points - s - 2; i++) {
                    bestRunPoints = inter;
                    if (costMat[bestRunPoints[i] - 1][bestRunPoints[i + s - 1] - 1] == 0) {
                        continue;
                    }
                    if (costMat[bestRunPoints[i + s + 1] - 1][bestRunPoints[i] - 1] == 0) {
                        continue;
                    }
                    if (costMat[bestRunPoints[i + s] - 1][bestRunPoints[i - 1] - 1] == 0) {
                        continue;
                    }
                    if (costMat[bestRunPoints[i + 1] - 1][bestRunPoints[i + s] - 1] == 0) {
                        continue;
                    }
                    int cost = int(bestRun);
                    int oldCost = Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i - 1])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + 1]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s - 1])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s + 1])));
                    int temp = bestRunPoints[i];
                    bestRunPoints[i] = bestRunPoints[i + s];
                    bestRunPoints[i + s] = temp;
                    /*for (int j = 0; j < num_points + extra; j++) {
                        cost += Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[j])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[j + 1])));
                    }*/
                    int newCost = Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i - 1])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + 1]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s - 1])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s]))) + 
                                  Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s])), GetVariableI("jsap_tsp_point" + Text::FormatInt(bestRunPoints[i + s + 1])));
                    cost -= oldCost - newCost;
                    if (cost < bestRun) {
                        inter = bestRunPoints;
                        string results_points;
                        for (int k = 0; k < int(bestRunPoints.Length); k++) {
                            results_points += " " + GetVariableI("jsap_tsp_point_name" + Text::FormatInt(bestRunPoints[k]));
                        }
                        bestRun = cost;
                        bestRunPoints_str = results_points;
                        SetVariable("jsap_tsp_best", bestRun);
                        SetVariable("jsap_tsp_best_points_str", bestRunPoints_str);
                    }
                }
            }
            bestRunPoints = inter;
        }
        if(UI::Button("Closest point")) {
            auto cam = GetCurrentCamera();
            if (@cam != null) {
                float bestDist = 9999999;
                for (int i = 1; i < int(num_points); i++) {
                    float dist = Distance(cam.Location.Position.ToString(), GetVariableI("jsap_tsp_point" + i));
                    if (dist < bestDist) {
                        bestDist = dist;
                        closestCpName = GetVariableI("jsap_tsp_point_name" + i);
                    }
                }
            }
        }
        UI::SameLine();
        UI::Text(closestCpName);
    }

    UI::End();
}

int SelStep(const int&in from, const array<array<float>>&in costMatInp, const array<array<float>>&in pherInp) {
    array<float> costs(num_points);
    float sum = 0;
    for (int y = 0; y < num_points; y++) {
        if (costMatInp[y][from-1] == 0) {
            costs[y] = 0;
            continue;
        }
        costs[y] = Math::Pow(pherInp[y][from - 1], alpha) * Math::Pow(1/costMatInp[y][from - 1], beta);
        sum += costs[y];
    }
    if (sum == 0) {
        return -1;
    }
    return RandIndexDistribution(costs, sum) + 1;
}

int RandIndexDistribution(array<float> inp, const float&in sum_inp) {
    float rand = Math::Rand(0.0, 1.0) * sum_inp;
    array<float> inter = inp;
    inter.SortDesc();
    float sum = 0;
    for (int i = 0; i < num_points; i++) {
        sum += inter[i];
        if (sum > rand) {
            return inp.Find(inter[i]);
        }
    }
    return 0;
}

/*int RandIndexDistribution(array<float> inp, const float&in sum_inp) {
    float rand = Math::Rand(0.0, 1.0) * sum_inp;
    float sum = 0;
    for (int i = 0; i < num_points; i++) {
        sum += inp[i];
        if (sum > rand) {
            return i;
        }
    }
    return 0;
}*/

int IndexFromPointName(const string&in inp) {
    for (int i = 0; i < num_points; i++) {
        if (GetVariableI("jsap_tsp_point_name" + Text::FormatInt(i + 1)) == inp) {
            return i;
        }
    }
    return -1;
}

array<array<float>> ConstructCostMat() {
    array<array<float>> res(num_points);
    array<float> row(num_points);
    float inter;
    for (int i = 0; i < num_points; i++) {
        res[i] = row;
    }
    for (int i = 0; i < num_points; i++) {
        res[i][i] = 0;
        for (int j = i + 1; j < num_points; j++) {
            inter = Distance(GetVariableI("jsap_tsp_point" + Text::FormatInt(i + 1)), GetVariableI("jsap_tsp_point" + Text::FormatInt(j + 1)));
            res[i][j] = inter;
            res[j][i] = inter;
        }
    }

    return res;
}

array<array<float>> MatMulScal(const array<array<float>>&in inp, const float&in scalar) {
    array<array<float>> res = inp;
    for (int i = 0; i < int(inp.Length); i++) {
        for (int j = 0; j < int(inp[0].Length); j++) {
            res[i][j] *= scalar;
        }
    }
    return res;
}

array<float> DivArray(const array<float>&in inp, const float&in div) {
    array<float> res(inp.Length);
    for (int i = 0; i < int(inp.Length); i++) {
        res[i] = inp[i] / div;
    }
    return res;
}

float SumArrayElements(const array<float>&in some_array){
    float sum = 0;
    for (int k = 0; k < int(some_array.Length); k++){
        sum += some_array[k];
    }
    return sum;
}

float Distance(const string&in inpstr1, const string&in inpstr2) {
    vec3 inp1 = Text::ParseVec3(inpstr1);
    vec3 inp2 = Text::ParseVec3(inpstr2);
    return Math::Distance(inp1, inp2);//Math::Sqrt(Math::Pow((inp1.x-inp2.x), 2) + Math::Pow((inp1.y-inp2.y), 2) + Math::Pow((inp1.z-inp2.z), 2));
}

string GetVariableI(const string&in inp) {
    string inter;
    GetVariable(inp, inter);
    return inter;
}
