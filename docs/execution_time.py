import random as r
import pandas as pd, numpy as np
import matplotlib.pyplot as plt

def simulate(fn_steps: int, init_nf: int, max_nf: int, p_add_f: float) -> int:
    steps = 0

    ks = [0] * init_nf

    # probability 1/len(ks), increment ki, ki <= T; len(ks) <= F.
    while ks[0] < fn_steps:
        add_fn = r.random() < p_add_f
        if add_fn and len(ks) < max_nf:
            ks.append(1)
        else: 
            # index of incrementable ks terms
            ks_arr = np.array(ks)
            incrementable_ixs = np.argwhere(ks_arr < fn_steps).T[0]

            i_ks = r.choice(incrementable_ixs)
            ks[i_ks] += 1
        steps += 1
    
    return steps

def relation_simulate_p(p: float, repeats: int = 1000) -> float:
    results = []
    for _ in range(repeats):
        results.append(simulate(fn_steps=5, init_nf=1, max_nf=10, p_add_f=p))
    return np.mean(np.array(results))


if __name__ == '__main__':
    
    # Plot relation_simulate_p for p from 0.0 to 1.0
    p_values = np.linspace(0.0, 1.0, 21)  # 21 points from 0.0 to 1.0
    mean_steps = [relation_simulate_p(p) for p in p_values]
    
    plt.figure(figsize=(10, 6))
    plt.plot(p_values, mean_steps, marker='o', linewidth=2, label='mean steps')
    plt.plot([0.0, 1.0], [5.0, 50.0], linestyle='--', color='gray', linewidth=1.5, label='linear relationship (0.0,5)→(1.0,50)')
    plt.xlabel('p (probability of adding f)', fontsize=12)
    plt.ylabel('Mean steps', fontsize=12)
    plt.title('Mean steps vs probability of adding function (p) (init_nf = 1, max_nf = 10, fn_steps = 5)', fontsize=14)
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig('relation_simulate_p.png', dpi=150)
    plt.show()
    
    print(f"Plot saved as 'relation_simulate_p.png'")
    
    # results = []
    # for i in range(300):
    #     results.append(simulate(fn_steps=5, init_nf=1, max_nf=10, p_add_f=0.50))
    # print(pd.DataFrame(results).describe())
    # p=0.50, fn_steps=5, max_nf=10, expectation ~ 60 ~ (5+1) * 10
    # p=0.10, fn_steps=5, max_nf=10, expectation ~ 45 ~ 